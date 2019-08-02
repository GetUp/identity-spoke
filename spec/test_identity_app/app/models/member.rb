class Member < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data

  has_many :custom_fields
  has_many :phone_numbers
  has_many :list_members
  has_many :member_subscriptions, dependent: :destroy
  has_many :subscriptions, through: :member_subscriptions
  has_many :contacts_received, class_name: 'Contact', foreign_key: 'contactee_id'
  has_many :contacts_made, class_name: 'Contact', foreign_key: 'contactor_id'
  has_many :contact_responses, through: :contacts_received

  scope :with_phone_numbers, -> {
    joins(:phone_numbers)
  }

  scope :with_phone_type, -> (phone_type) {
    with_phone_numbers
      .merge(PhoneNumber.send(phone_type))
  }

  scope :with_mobile, -> {
    with_phone_numbers
      .merge(PhoneNumber.mobile)
  }

  scope :with_landline, -> {
    with_phone_numbers
      .merge(PhoneNumber.landline)
  }

  def name
    [first_name, middle_names, last_name].select(&:present?).join(' ')
  end

  def name=(name)
    array = name.to_s.split
    self.first_name = nil
    self.middle_names = nil
    self.last_name = nil
    self.first_name = array.shift
    self.last_name = array.pop
    self.middle_names = array.join(' ') if array.present?
  end

  def phone
    phone_numbers.sort_by(&:updated_at).last.phone unless phone_numbers.empty?
  end

  def landline
    phone_numbers
      .landline
      .sort_by(&:updated_at)
      .last.try(:phone)
  end

  def mobile
    phone_numbers
      .mobile
      .sort_by(&:updated_at)
      .last.try(:phone)
  end

  def flattened_custom_fields
    custom_fields.inject({}) do |memo, custom_field|
      memo.merge({ :"#{custom_field.custom_field_key.name}" => custom_field.data })
    end
  end

  # update phone number
  def update_phone_number(new_phone_number, new_phone_type = nil, audit_data = nil)
    new_phone_number = new_phone_number.to_s
    unless phone_numbers.first.try(:phone) == new_phone_number
      if (phone_record = phone_numbers.find_by(phone: new_phone_number))
        phone_record.audit_data = audit_data
        phone_record.update!(updated_at: DateTime.now)
      else
        phone_number_attributes = { member_id: id, phone: new_phone_number}
        phone_number_attributes[:phone_type] = new_phone_type unless new_phone_type.nil?
        phone_number = PhoneNumber.new(phone_number_attributes)
        if phone_number.valid?
          phone_number.audit_data = audit_data
          phone_number.save!
        else
          Rails.logger.info "Phone number for #{id} not updated"
        end
      end
      true
    end
    false
  end

  def subscribe_to(subscription, reason = nil, subscribe_time = DateTime.now, audit_data = nil)
    return update_subscription(subscription, true, subscribe_time, reason, nil, audit_data)
  end

  def update_subscription(subscription, should_subscribe, event_time, reason = nil, unsub_mailing_id = nil, audit_data = nil)
    retried = false
    begin
      # Don't subscribe / re-sub anyone who is permanently unsub'd
      return false if self.unsubscribed_permanently?

      ms = self.member_subscriptions.find_or_initialize_by(subscription: subscription) do |member_sub|
        # Ensure new records have the time of this event
        member_sub.created_at = event_time
        member_sub.updated_at = event_time
      end

      # Only process this event if it's newer than the previous sub/unsub event or it's a new subscription
      if event_time > ms.updated_at || ms.new_record?
        ms.audit_data = audit_data
        if should_subscribe && !ms.unsubscribed_permanently?
          return ms.update!(
            unsubscribed_at: nil,
            unsubscribe_reason: nil,
            updated_at: event_time,
            subscribe_reason: (reason || 'not specified'),
          )
        elsif !should_subscribe && ms.unsubscribed_at.nil?
          return ms.update!(
            unsubscribed_at: event_time,
            unsubscribe_reason: (reason || 'not specified'),
            unsubscribe_mailing_id: unsub_mailing_id,
            updated_at: event_time,
          )
        end
      end
      return false
    rescue ActiveRecord::RecordNotUnique
      # Safe to always retry because there must be a DB-level unique constraint,
      # meaning there cannot be any duplicates at the moment, so next try will
      # find the existing record in find_or_initialize_by
      retry
    rescue ActiveRecord::RecordInvalid => e
      # Retry AR uniquness validation errors once, could be race condition...
      if !retried && e.record.errors.details.dig(:member, 0, :error) == :taken
        retried = true
        retry
      else
        # Already retried, likely to be duplicate data already in the db, abort
        raise e
      end
    end
  end

  def unsubscribed_permanently?
    if member_subscription = member_subscriptions.find_by(subscription_id: Subscription::EMAIL_SUBSCRIPTION)
      return member_subscription.unsubscribed_permanently?
    else
      return false
    end
  end

  def self.upsert_member(hash, entry_point: '', audit_data: {}, ignore_name_change: false, strict_member_id_match: false)
    ApplicationRecord.transaction do
      # fail if there's no data
      if hash.nil?
        Rails.logger.info hash
        return nil
      end

      member_id = hash[:member_id]
      # fail if there's no valid email address
      external_matched_members = if hash[:external_ids].present?
                                   hash[:external_ids].map do |system, id|
                                     Member.find_by_external_id(system, id)
                                   end.compact.uniq
                                 end
      email = Cleanser.cleanse_email(hash.try(:[], :emails).try(:[], 0).try(:[], :email))
      phone = PhoneNumber.standardise_phone_number(hash.try(:[], :phones).try(:[], 0).try(:[], :phone))
      guid = hash[:guid]

      # reject the email address if it's invalid
      email = nil unless Cleanser.accept_email?(email)

      # then create with the passed entry point
      # use rescue..retry to avoid errors where two Sidekiq processes try to insert different actions at the same time
      member_created = false

      begin
        begin
          member = Member.find(member_id) if !member && member_id.present?
        rescue ActiveRecord::RecordNotFound
          raise Exception.new('Member upsert rejected: Strict member id match found no match') if strict_member_id_match
        end
        member = external_matched_members.first if !member && external_matched_members.present? && external_matched_members.length == 1

        unless member || email || phone || guid
          Rails.logger.info('Rejected upsert for member because there was no email or phone or guid found')
          return nil
        end

        member = Member.find_by(email: email) if !member && email.present?
        if !hash[:ignore_phone_number_match]
          member = Member.find_by_phone(phone) if !member && phone.present?
        end
        member = Member.find_by(guid: guid) if !member && guid.present?
        unless member
          member = Member.new(email: email, entry_point: entry_point)
          member.audit_data = audit_data
          member.save!
          member_created = true
          ignore_name_change = false
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      member.audit_data = audit_data

      if hash.key?(:external_ids)
        hash[:external_ids].each do |system, external_id|
          raise "External ID for #{system} cannot be blank" if external_id.blank?

          member.update_external_id(system, external_id, audit_data)
        end
      end

      # Don't update further details if upsert data is older than member.updated_at
      return member if !member_created && hash[:updated_at].present? && hash[:updated_at] < member.updated_at

      # Handle names
      unless ignore_name_change
        new_name = {
          first_name: hash[:firstname],
          middle_names: hash[:middlenames],
          last_name: hash[:lastname]
        }

        old_name = {
          first_name: member.first_name,
          middle_names: member.middle_names,
          last_name: member.last_name
        }

        if hash.key?(:name)
          firstname, lastname = hash[:name].split(' ')
          new_name[:first_name] = firstname unless firstname.empty?
          new_name[:last_name] = lastname unless lastname.empty?
        end
        member.update!(combine_names(old_name, new_name))
      end

      if hash.key?(:custom_fields)
        hash[:custom_fields].each do |custom_field_hash|
          if custom_field_hash[:value].present?
            custom_field_key = CustomFieldKey.find_or_initialize_by(name: custom_field_hash[:name])
            custom_field_key.audit_data = audit_data
            custom_field_key.save! if custom_field_key.new_record?
            member.add_or_update_custom_field(custom_field_key, custom_field_hash[:value], audit_data)
          end
        end
      end

      # if there are phone numbers present, save them to the member
      if hash.key?(:phones) && !hash[:phones].empty?
        hash[:phones].each do |phone_number|
          member.update_phone_number(phone_number[:phone], nil, audit_data)
        end
      end

      # if there are addresses present, save them to the member
      if hash.key?(:addresses) && !hash[:addresses].empty?
        address = hash[:addresses][0]
        # Don't update with any address containing only empty strings
        if address.except(:country).values.any?(&:present?)
          member.update_address(address, audit_data)
        end
      end

      if hash.key?(:subscriptions)
        hash[:subscriptions].each do |sh|
          next unless (
            subscription = Subscription.find_by(id: sh[:id]) || Subscription.find_by(slug: sh[:slug])
          ) || Settings.options.allow_upsert_create_subscriptions

          if subscription.blank? && Settings.options.allow_upsert_create_subscriptions
            if sh[:create].eql?(true)
              subscription = Subscription.create!(name: sh[:name], slug: sh[:slug])
            else
              Rails.logger.error "Subscription not found #{sh[:slug]}"
            end
          end

          case sh[:action]
          when 'subscribe'
            member.subscribe_to(subscription, sh[:reason], DateTime.now, audit_data)
          when 'unsubscribe'
            member.unsubscribe_from(subscription, sh[:reason], DateTime.now, nil, audit_data)
          end
        end
      end

      ## if member was created with upsert and setting is opted in by default
      ## then create default subscriptions that were not passed with query hash
      if member_created && Settings.options.default_member_opt_in_subscriptions
        member.upsert_default_subscriptions(hash, entry_point, audit_data)
      end

      if hash.key?(:skills)
        hash[:skills].each do |s|
          if (skill = Skill.where('name ILIKE ?', s[:name]).order(created_at: :desc).first)
            begin
              new_member_skill = MemberSkill.new(member: member, skill: skill, rating: s[:rating].try(:to_i), notes: s[:notes], audit_comment: audit_data)
              new_member_skill.audit_data = audit_data
              new_member_skill.save!
            rescue ActiveRecord::RecordInvalid
              # Skill already assigned, no action needed
            end
          end
        end
      end

      if hash.key?(:resources)
        hash[:resources].each do |s|
          if (resource = Resource.where('name ILIKE ?', s[:name]).order(created_at: :desc).first)
            begin
              new_member_resource = MemberResource.new(member: member, resource: resource, notes: s[:notes], audit_comment: audit_data)
              new_member_resource.audit_data = audit_data
              new_member_resource.save!
            rescue ActiveRecord::RecordInvalid
              # Resource already assigned, no action needed
            end
          end
        end
      end

      if hash.key?(:organisations)
        hash[:organisations].each do |s|
          if (organisation = Organisation.where('name ILIKE ?', s[:name]).order(created_at: :desc).first)
            begin
              new_organisation_membership = OrganisationMembership.new(member: member, organisation: organisation, notes: s[:notes], audit_comment: audit_data)
              new_organisation_membership.audit_data = audit_data
              new_organisation_membership.save!
            rescue ActiveRecord::RecordInvalid
              # Organisation already assigned, no action needed
            end
          end
        end
      end

      member
    end
  end

  def self.find_by_phone(phone)
    PhoneNumber.find_by_phone(phone).try(:member)
  end

  def self.combine_names(old_name, new_name)
    old_name = old_name.slice(:first_name, :middle_names, :last_name)
    new_name = new_name.slice(:first_name, :middle_names, :last_name)

    is_new_name = false
    combined_name = old_name

    new_name.each do |key, new_value|
      new_value = new_value.to_s.strip
      current_value = old_name[key].to_s.strip
      if current_value.downcase.starts_with?(new_value.downcase) || new_value.downcase.starts_with?(current_value.downcase)
        if new_value.length > current_value.length
          combined_name[key.to_sym] = new_value
        end
      else
        is_new_name = true
      end
    end

    if is_new_name
      combined_name = new_name.select { |k, v| v.present? }
    end

    return { first_name: nil, middle_names: nil, last_name: nil }.merge(combined_name)
  end

  def unsubscribe_from(subscription, reason = nil, unsubscribe_time = DateTime.now, unsub_mailing_id = nil, audit_data = nil)
    return update_subscription(subscription, false, unsubscribe_time, reason, unsub_mailing_id, audit_data)
  end

  def is_subscribed_to?(subscription)
    !!self.member_subscriptions.find_by(subscription: subscription, unsubscribed_at: nil)
  end
end
