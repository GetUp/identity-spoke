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
    @retries = 0
  end

  def call
    ApplicationRecord.transaction do
      # fail if there's no data
      next if payload.blank?

      member, member_created = find_or_create_member(payload)

      next if member.blank?

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
  rescue StandardError
    # Possibility of race conditions in the transaction.
    # Most likely from different CSL imports trying to upsert the same member.
    # Transaction will clean up after itself, and then retry again.
    # Have a limit of 3 retries so that we don't retry forever.
    @retries += 1
    retry if @retries < 3
    raise
  end

  private

  attr_reader :payload, :entry_point, :ignore_name_change

  def find_or_create_member(payload)
    external_matched_members = payload[:external_ids]&.map do |system, id|
      Member.find_by_external_id(system, id)
    end&.compact&.uniq

    email = Cleanser.cleanse_email(payload.try(:[], :emails).try(:[], 0).try(:[], :email))
    phone = PhoneNumber.standardise_phone_number(payload.try(:[], :phones).try(:[], 0).try(:[], :phone))
    guid = payload[:guid]

    email = nil unless Cleanser.accept_email?(email)

    member_created = false
    member = external_matched_members.first if external_matched_members.present? && external_matched_members.length == 1

    unless member || email || phone || guid
      Rails.logger.info('Rejected upsert for member because there was no email or phone or guid found')
      return nil, false
    end

    member = Member.find_by(email: email) if !member && email.present?
    if !payload[:ignore_phone_number_match]
      member = Member.find_by_phone(phone) if !member && phone.present?
    end
    member = Member.find_by(guid: guid) if !member && guid.present?

    unless member
      member = Member.create!(email: email, entry_point: entry_point)
      member_created = true
    end

    [member, member_created]
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
