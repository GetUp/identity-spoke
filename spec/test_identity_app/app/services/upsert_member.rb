##
# Standard service for updating or inserting a member.
#
# Given a `cons_hash` payload parameter (see API documentation for
# details) looks up an existing member and update them with the values
# in the payload, or if not found creates the member.
#
# Member lookup is performed using the following payload data:
#  * First email address given (all others are ignored)
#  * First phone number given (others will be upserted, phone numbers will
#    be ignored if payload key `ignore_phone_number_match` evaluates to
#    true)
#  * First existing external systems id given
#  * `member_id` - if given the member *must* already exist else an error is
#    thrown
#  * `guid` - if given the member *must* already exist else an error is
#    thrown
#
# At least one of the above payload values must be provided, otherwise
# an error is thrown.
#
# Any email given in the payload will be filtered first through
# `Cleanser`, and any phone numbers given will be normalised via the
# PhoneNumber.
#
# If `Settings.options.allow_subscribe_via_upsert_member` is true,
# then the member's subscriptions will be updated using the payload
# `subscriptions` parameter. If `new_member_opt_in` is also true, any
# members created as part of the subscription process will also be
# subscribed, but using the defaul subscriptions.
#
# Will raise an exception if either the `member_id` or `guid` payload
# values are set an a matching member is not found, if not enough data
# was provided to lookup or create a unique member record, or if any
# matched member is already ghosted.
#
# Will not change an existing member's name unless
# `ignore_name_change` is true.
#
class UpsertMember < IdentityBaseService
  def initialize(payload,
                 entry_point: '',
                 ignore_name_change: false,
                 new_member_opt_in: nil)
    @payload = payload
    @entry_point = entry_point
    @ignore_name_change = ignore_name_change
    @new_member_opt_in = new_member_opt_in
    if @new_member_opt_in.nil?
      @new_member_opt_in = Settings.options.default_member_opt_in_subscriptions
    end
  end

  def call
    ApplicationRecord.transaction do
      begin
        member, member_created = find_or_create_member(payload)
      rescue StandardError => e
        Rails.logger.warn {
          "Rejected upsert due to member find/create error: #{e}"
        }
        raise
      end

      upsert_external_ids(payload[:external_ids], member) if payload.key?(:external_ids)

      # Don't update further details if upsert data is older than member.updated_at
      next member if !member_created && payload[:updated_at].present? && payload[:updated_at] < member.updated_at

      # Don't update if we've attempted to ghost the member!
      raise "Attempt to upsert_member on a ghosted member (member_id: #{member.id}, data: #{payload})" if member.ghosting_started?

      upsert_emails(payload, member) if payload[:apply_email_address_changes] && payload.key?(:emails) && !member_created
      upsert_names(payload, member) if !ignore_name_change || member_created
      upsert_custom_fields(payload[:custom_fields], member) if payload.key?(:custom_fields)
      upsert_phone_numbers(payload[:phones], member) if payload[:phones].present?
      upsert_addresses(payload[:addresses], member) if payload[:addresses].present?

      if Settings.options.allow_subscribe_via_upsert_member
        if member_created && @new_member_opt_in
          member.upsert_default_subscriptions(payload, entry_point)
        end
        upsert_subscriptions(payload[:subscriptions], member) if payload.key?(:subscriptions)
      end

      upsert_skills(payload[:skills], member) if payload.key?(:skills)
      upsert_resources(payload[:resources], member) if payload.key?(:resources)
      upsert_organisation(payload[:organisations], member) if payload.key?(:organisations)

      member
    end
  end

  private

  attr_reader :payload, :entry_point, :ignore_name_change

  def find_or_create_member(payload)
    member_id = payload[:member_id]
    if member_id.present?
      return [Member.find_sole_by(id: member_id), false]
    end

    guid = payload[:guid]
    if guid.present?
      return [Member.find_sole_by(guid: guid), false]
    end

    # For member lookup, it's good enough to ignore invalid email
    # addresses and phone numbers, since if they are invalid, we can't
    # perform a lookup for them

    email = Cleanser.cleanse_email(payload.try(:[], :emails).try(:[], 0).try(:[], :email))
    email = nil unless Cleanser.accept_email?(email)

    phone = PhoneNumber.standardise_phone_number(
      payload.try(:[], :phones).try(:[], 0).try(:[], :phone)
    )

    external_matched_members = payload[:external_ids]&.map do |system, id|
      Member.find_by_external_id(system, id)
    end&.compact&.uniq
    member = external_matched_members.first if external_matched_members.present? && external_matched_members.length == 1

    unless member || email || phone
      raise "Not enough information provided to find or create a member"
    end

    # Both the email and phone lookups below catch both "not found" &
    # "too many" here since if not found then it should be created,
    # but also if more than one is found, it's not possible to
    # reliably disambiguate in an automated way, so create a duplicate
    # and let something/someone else handle it.

    if !member && email.present?
      begin
        member = Member.find_sole_by(email: email)
      rescue ActiveRecord::RecordNotFound
        # pass
      rescue ActiveRecord::SoleRecordExceeded
        # pass
      end
    end

    if !member && phone.present? && !payload[:ignore_phone_number_match]
      begin
        member = PhoneNumber.find_sole_by(phone: phone).member
      rescue ActiveRecord::RecordNotFound
        # pass
      rescue ActiveRecord::SoleRecordExceeded
        # pass
      end
    end

    member_created = false
    if !member
      member = Member.create!(email: email, entry_point: entry_point)
      member_created = true
    end

    return [member, member_created]
  end

  def upsert_external_ids(external_ids, member)
    external_ids.each do |system, external_id|
      raise "External ID for #{system} cannot be blank" if external_id.blank?

      member.update_external_id(system, external_id)
    end
  end

  def upsert_custom_fields(custom_fields, member)
    custom_fields.each do |custom_field_hash|
      if custom_field_hash[:value].present?
        custom_field_key = CustomFieldKey.find_or_create_by!(name: custom_field_hash[:name])
        member.add_or_update_custom_field(custom_field_key, custom_field_hash[:value])
      end
    end
  end

  def upsert_emails(payload, member)
    # Multiple email addresses aren't currently supported by the data model,
    # so just upsert the first email address present in the payload.
    email = Cleanser.cleanse_email(payload.try(:[], :emails).try(:[], 0).try(:[], :email))
    member.email = email if Cleanser.accept_email?(email)
  end

  def upsert_names(payload, member)
    new_name = {
      first_name: payload[:firstname],
      middle_names: payload[:middlenames],
      last_name: payload[:lastname]
    }

    old_name = {
      first_name: member.first_name,
      middle_names: member.middle_names,
      last_name: member.last_name
    }

    if payload.key?(:name)
      firstname, lastname = payload[:name].split(' ')
      new_name[:first_name] = firstname if firstname.present?
      new_name[:last_name] = lastname if lastname.present?
    end

    member.update!(NameHelper.combine_names(old_name, new_name))
  end

  def upsert_phone_numbers(phone_numbers, member)
    phone_numbers.each do |phone_number|
      member.update_phone_number(phone_number[:phone])
    end
  end

  def upsert_addresses(addresses, member)
    address = addresses.first
    # Don't update with any address containing only empty strings
    if address.except(:country).values.any?(&:present?)
      member.update_address(address)
    end
  end

  def upsert_subscriptions(subscriptions, member)
    subscriptions.each do |s|
      subscription = Subscription.find_by(id: s[:id]) || Subscription.find_by(slug: s[:slug])

      if subscription.blank?
        if Settings.options.allow_upsert_create_subscriptions && s[:create].eql?(true)
          subscription = Subscription.create!(name: s[:name], slug: s[:slug])
        else
          Rails.logger.error "Subscription not found #{s[:slug]}"
          next
        end
      end

      case s[:action]
      when 'subscribe'
        member.subscribe_to(subscription, reason: s[:reason])
      when 'unsubscribe'
        member.unsubscribe_from(subscription, reason: s[:reason])
      end
    end
  end

  def upsert_skills(skills, member)
    skills.each do |s|
      if (skill = Skill.where('name ILIKE ?', s[:name]).order(created_at: :desc).first)
        MemberSkill.create_with(rating: s[:rating].try(:to_i)).find_or_create_by!(member: member, skill: skill, notes: s[:notes])
      end
    end
  end

  def upsert_resources(resources, member)
    resources.each do |r|
      if (resource = Resource.where('name ILIKE ?', r[:name]).order(created_at: :desc).first)
        MemberResource.find_or_create_by!(member: member, resource: resource, notes: r[:notes])
      end
    end
  end

  def upsert_organisation(organisations, member)
    organisations.each do |o|
      if (organisation = Organisation.where('name ILIKE ?', o[:name]).order(created_at: :desc).first)
        OrganisationMembership.find_or_create_by!(member: member, organisation: organisation, notes: o[:notes])
      end
    end
  end
end
