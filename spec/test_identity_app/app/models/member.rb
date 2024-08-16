# == Schema Information
#
# Table name: members
#
#  id               :integer          not null, primary key
#  email            :text
#  contact          :json
#  created_at       :datetime
#  updated_at       :datetime
#  joined_at        :datetime
#  crypted_password :text
#  guid             :text
#  action_history   :json
#  reset_token      :text
#  admin            :boolean
#  authy_id         :integer
#  volunteer        :boolean
#  role_id          :integer
#  last_donated     :datetime
#  donations_count  :integer
#  average_donation :float
#  highest_donation :float
#  mosaic_group     :text
#  mosaic_code      :text
#  entry_point      :text
#

require 'zip'

class Member < ApplicationRecord

  # relationships
  belongs_to :role, optional: true
  has_many :list_members
  has_many :lists, through: :list_members, dependent: :destroy
  has_many :conditional_list_members
  has_many :conditional_lists, through: :conditional_list_members, dependent: :destroy
  has_many :event_rsvps
  has_many :events, through: :event_rsvps
  has_many :hosted_events, class_name: 'Event', foreign_key: 'host_id'
  has_many :area_memberships, dependent: :destroy
  has_many :areas, through: :area_memberships
  has_many :group_members
  has_many :groups, through: :group_members
  has_many :journey_coordinators
  has_many :coordinated_journeys, through: :journey_coordinators, source: :journey
  has_many :member_skills
  has_many :skills, through: :member_skills
  has_many :organisation_memberships
  has_many :organisations, through: :organisation_memberships
  has_many :member_resources
  has_many :resources, through: :member_resources
  has_many :member_actions
  has_many :actions, through: :member_actions
  has_many :create_petition_actions, -> { merge(Action.create_petition) }, source: :action, through: :member_actions
  has_many :campaigns, through: :actions
  has_many :issues, through: :campaigns
  has_many :issue_categories, through: :issues

  has_many :member_action_consents, through: :member_actions

  has_many :member_mailings
  has_many :mailings, through: :member_mailings
  has_many :mailing_logs, class_name: 'Mailer::MailingLog'
  has_one :members_on_ice
  has_one :one_month_active
  has_one :three_month_active
  has_one :members_on_ice_exclusion
  has_one :spam_exclude
  has_one :member_open_click_rate

  has_many :smses, class_name: 'TextBlasts::SMS'
  has_many :text_blasts, -> { order 'text_blasts.created_at DESC' }, through: :smses

  has_many :notification_endpoints, class_name: 'WebNotifications::NotificationEndpoint'
  has_many :member_notifications, class_name: 'WebNotifications::MemberNotification'
  has_many :notifications, through: :member_notifications

  has_many :donations, class_name: 'Donations::Donation'
  has_many :regular_donations, class_name: 'Donations::RegularDonation'
  has_many :member_journeys
  has_many :journeys, through: :member_journeys
  has_many :notes, -> { order 'notes.created_at DESC' }
  has_many :notes_written, class_name: 'Note', foreign_key: 'user_id'
  has_many :follow_ups
  has_many :follow_ups_by, class_name: 'FollowUp', foreign_key: 'contactee_id'
  has_many :member_volunteer_tasks
  has_many :volunteer_tasks, through: :member_volunteer_tasks
  has_many :call_sessions
  has_many :phone_numbers, -> { order 'phone_numbers.updated_at DESC' }, dependent: :destroy
  has_many :addresses, -> { order 'addresses.updated_at DESC' }, dependent: :destroy
  has_many :member_subscriptions, dependent: :destroy
  has_many :member_subscription_events, through: :member_subscriptions
  has_many :subscribables, through: :member_subscription_events

  has_many :subscriptions, through: :member_subscriptions

  has_many :custom_fields
  has_many :custom_field_keys, through: :custom_fields

  has_many :contacts_received, class_name: 'Contact', foreign_key: 'contactee_id'
  has_many :contacts_made, class_name: 'Contact', foreign_key: 'contactor_id'
  has_many :contact_responses, through: :contacts_received

  has_many :member_demographic_groups, class_name: 'Demographics::MemberDemographicGroup'
  has_many :demographic_groups, class_name: 'Demographics::DemographicGroup', through: :member_demographic_groups

  has_many :member_external_ids
  has_many :dedupe_blocks

  has_many :search_authorships, class_name: 'Search', foreign_key: 'author_id'
  has_many :list_authorships, class_name: 'List', foreign_key: 'author_id'
  has_many :sync_authorships, class_name: 'Sync', foreign_key: 'author_id'
  has_many :flow_authorships, class_name: 'Flow', foreign_key: 'author_id'

  has_many :anonymization_logs

  scope :with_member_data, -> {
    includes(:regular_donations, :donations, :addresses, :areas)
  }

  scope :authors_matching, ->(authorship, query) {
    joins(authorship)
      .where("email ILIKE ? OR #{BY_NAME_WHERE_SQL}", "%#{query}%", "%#{query}%")
      .uniq
  }

  scope :with_email, -> {
    where.not(email: nil)
  }

  scope :with_phone_numbers, -> {
    joins(:phone_numbers)
  }

  scope :with_phone_type, ->(phone_type) {
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

  scope :active_regular_donor, -> {
    joins(:regular_donations).merge(Donations::RegularDonation.active)
  }

  scope :not_active_regular_donor, -> {
    where.not(id: active_regular_donor)
  }

  scope :active_petition_starter, -> {
    joins(member_actions: { action: :campaign })
      .merge(Action.create_petition)
      .merge(Campaign.unfinished_or_recently_finished)
  }

  scope :not_active_petition_starter, -> {
    where.not(id: active_petition_starter)
  }

  scope :can_be_ghosted, -> {
    if Settings.ghoster.ghost_active_petition_starters
      not_active_regular_donor
    else
      not_active_regular_donor.not_active_petition_starter
    end
  }

  scope :can_be_forcibly_ghosted, -> {
    not_active_regular_donor
  }

  scope :subscriptions_with_slug, ->(subscription_slug) {
    joins(member_subscriptions: :subscription).where(member_subscriptions: {
      subscriptions: { slug: subscription_slug },
      unsubscribed_at: nil
    })
  }

  scope :admins, -> {
    where.not(role: nil)
  }

  attr_accessor :password

  validates_uniqueness_of :email, allow_blank: true, allow_nil: true, if: Proc.new { |m| m.new_record? || m.email_changed? }, message: 'is already taken. Click Sign In above to sign in.'
  EMAIL_VALIDATION_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\Z/i.freeze

  # This WHERE query part is indexed with a GIN index,
  # so it should run pretty fast and its usage is encouraged.
  sql = <<~SQL
    TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')) ILIKE ?
  SQL
  BY_NAME_WHERE_SQL = sql.freeze

  validates_format_of :email, with: EMAIL_VALIDATION_REGEX, allow_nil: true

  before_save { |member| member.email = member.email.try(:downcase).try(:strip) }
  validates_presence_of :password, if: :password_present
  validates_length_of :password, within: 16..40, if: :password_present

  # Use `by_name` to do full text searches on the indexed full name.
  scope :by_name, ->(name, search_type = nil) {
    if search_type == :contains
      name = "%#{name}%"
    end

    where(BY_NAME_WHERE_SQL, name)
  }

  # Getters
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

  def flattened_custom_fields
    custom_fields.inject({}) do |memo, custom_field|
      memo.merge({ :"#{custom_field.custom_field_key.name}" => custom_field.data })
    end
  end

  def vocative_or_first_name
    FirstName.find_by('lower(first_name) = lower(?)', self.first_name).try(:vocative) || self.first_name
  end

  def address
    return addresses.sort_by(&:updated_at).last unless addresses.empty?
  end

  def postcode
    address.try(:postcode)
  end

  def phone
    phone_numbers.sort_by(&:updated_at).last.phone unless phone_numbers.empty?
  end

  def mobile_if_can_be_detected_or_phone
    mobile = phone_numbers.mobile.first
    return mobile if mobile.present?

    phone_numbers.not_landline.first
  end

  def actions_count
    actions.length
  end

  # Get the most recent changed consent per consent_text_id
  def current_consents
    # Memoize. The `1` is in the distinct query because
    # eager_load will do a thing where it sets up all the columns,
    # and rails won't produce a valid query unless there is a column
    # after `DISTINCT ON (...)`
    # Rails 6.1 "fixed" the eager_load method, no more strange `1` in the distinct query
    @current_consents ||= MemberActionConsent.select('DISTINCT ON (member_action_consents.consent_text_id) member_action_consents.*')
                                             .joins(:member_action)
                                             .eager_load(:consent_text)
                                             .where.not(consent_level: :no_change)
                                             .where('member_actions.member_id': id)
                                             .order(:consent_text_id)
                                             .order('member_action_consents.created_at DESC')
                                             .order('member_action_consents.id DESC')
                                             .to_a # Do this to avoid errors on `count`
  end

  # update address
  def update_address(new_address)
    old_address_id = address.try(:id)

    address_attributes = {
      line1: new_address[:line1] || new_address[:addr1],
      line2: new_address[:line2] || new_address[:addr2],
      town: new_address[:town] || new_address[:city],
      postcode: new_address[:postcode] || new_address[:zip],
      state: new_address[:state],
      country: new_address[:country],
    }

    if (new_address = addresses.find_by(address_attributes))
      new_address.touch!
    else
      new_address = addresses.create!(address_attributes)
    end

    unless new_address.try(:id) == old_address_id
      # update_address will be called for newly created members
      # inside a transaction, so in order to reduce retries inside
      # UpdateMemberAreasWorker we schedule it 5 seconds in the
      # future.
      UpdateMemberAreasWorker.perform_in(5.seconds, id)
      return true
    end

    false
  end

  def update_phone_number(new_phone_number, new_phone_type = nil)
    # The primary phone number is the one a member has most recently told us about.
    # Do not update if they have already told us this phone number and it is already the most recent
    # If they have told us about it in the past and it is not the primary one, then make it the primary one
    # If it is a new phone number, create a new phone number and it will be the primary one

    new_phone_number = PhoneNumber.standardise_phone_number(new_phone_number.to_s)
    return false if phone_numbers.first.try(:phone) == new_phone_number

    if (phone_record = phone_numbers.find_by(phone: new_phone_number))
      # Make it most recently updated it so it becomes the primary phone number
      phone_record.update! updated_at: DateTime.now
      return true
    end

    phone_number_attributes = { member_id: id, phone: new_phone_number }
    phone_number_attributes[:phone_type] = new_phone_type unless new_phone_type.nil?
    phone_number = PhoneNumber.new(phone_number_attributes)

    if phone_number.valid?
      phone_number.save
      return true
    else
      Rails.logger.info "Phone number for member #{id} not updated"
      return false
    end
  end

  def update_external_id(system, external_id)
    errors = 0
    begin
      member_external_ids.find_or_create_by!(system: system, external_id: external_id)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      errors += 1
      retry if errors < 2

      Rails.logger.error "Can't create member_external_id for member #{id} - would create a duplicate: #{system} #{external_id}"
      raise
    end
  end

  def get_external_ids(system)
    member_external_ids.where(system: system).map(&:external_id)
  end

  def add_or_update_custom_field(custom_field_key, data)
    custom_field = CustomField.find_or_create_by!(
      member_id: id, custom_field_key: custom_field_key
    )
    custom_field.update!(data: data)
  end

  # Recalculate donation information
  def recalculate_donation_statistics
    total_donations = 0.0
    highest_donation = 0.0
    last_donation = nil
    for donation in donations
      total_donations += donation.amount
      highest_donation = donation.amount if donation.amount > highest_donation
      if last_donation.nil? || donation.created_at > last_donation
        last_donation = donation.created_at
      end
    end

    update!(
      last_donated: last_donation,
      donations_count: donations.length,
      highest_donation: highest_donation,
      average_donation: (!donations.empty? ? (total_donations / donations.length) : 0)
    )
  end

  def activity_history
    (
      audits + associated_audits + member_mailings + member_actions + member_action_consents +
      smses + member_notifications + contacts_received
    ).sort_by(&:created_at).reverse
  end

  def has_regular_donation?
    !regular_donations.where(ended_at: nil).empty?
  end

  # Update the area memberships of member
  def update_areas
    # First, find/verify the canonical address
    if address.present?
      address_attr = address.attributes.with_indifferent_access.slice(
        :line1, :line2, :town, :postcode, :state, :country
      )
      canonical_address = CanonicalAddress.search(address_attr)
      if canonical_address&.id != address.canonical_address&.id
        address.canonical_address = canonical_address;
        # Don't set updated_at to avoid changing address precedence
        address.save!(touch: false)
      end
    end
    if canonical_address
      areas = canonical_address.areas
    elsif (zip = Postcode.search(postcode))
      areas = AreaZip.where(zip: zip.zip).map(&:area)
      if Settings.geography.area_lookup.use_open_north_api
        api = OpenNorthAPI.new
        area_codes = api.get_boundaries_for_lat_lng(zip.latitude, zip.longitude)
        area_codes.each do |area_type, code|
          areas << Area.find_by(area_type: area_type, code: code)
        end
      end
      if Settings.geography.area_lookup.use_canadian_province_lookup
        canadian_province_lookup = CanadianProvinceLookup.new
        if (code = canadian_province_lookup.get_province_for_postcode(zip.zip))
          areas << Area.find_by(area_type: 'canada_province', code: code)
        end
      end
      # TODO: Legacy mosaic code - delete once all orgs who use this have migrated to the newer, more flexible approach
      mosaic = Mosaic::Mosaic.find_by(postcode: postcode.upcase.delete!(' '))
    end

    areas = (areas ||= []).uniq
    self.areas.clear
    self.areas << (areas || [])

    if Settings.geography.area_lookup.track_area_probabilities
      self.area_memberships.each do |area_membership|
        if zip
          # If using the member's postcode/zip to determine their location, the probability
          # that they are in each area is equal to the proportion of their postcode/zip
          # the area represents.
          prob = AreaZip.find_by(area: area_membership.area, zip: zip)&.proportion_of_zip
        elsif canonical_address
          # If the member's address is linked to a canonical address, the probability that they
          # are in each associated area is 1.000 (100% certain!)
          prob = 1.0
        end
        area_membership.probability = prob
        area_membership.save!
      end
    end

    # TODO: Legacy mosaic code - delete once all orgs who use this have migrated to the newer, more flexible approach
    if mosaic
      self.mosaic_group = mosaic.mosaic_group
      self.mosaic_code = mosaic.code
      save!
    end

    zip_source = zip || canonical_address
    if zip_source
      update_demographic_groups(zip_source.zip)
    end

    lat_lng_source = canonical_address || zip
    if lat_lng_source
      self.latitude = lat_lng_source.latitude
      self.longitude = lat_lng_source.longitude
      save!
    end
  end

  def update_demographic_groups(zip_string)
    if Demographics::DemographicTracking.permitted?(self, 'zip')
      new_demographics = Demographics::DemographicGroup.in_zip(zip_string)

      # Delete old demographic this member is linked to via a zip (the new zip doesn't include these demographics)
      self.member_demographic_groups.where(
        linked_via: 'zip'
      ).where.not(
        demographic_group_id: new_demographics.map(&:id)
      ).destroy_all

      # Ensure the member is linked to all the demographics for this zip
      new_demographics.each do |dg|
        self.member_demographic_groups.create_or_find_by!(demographic_group: dg, linked_via: 'zip')
      end
    else
      # Demographic tracking via zip is not permitted for this member, delete any demographic data linked via zip
      self.member_demographic_groups.where(linked_via: 'zip').destroy_all
    end
  end

  # Determines if the member is subscribed to at least one default subscription.
  def subscribed?
    subscribed = false
    Subscription.defaults.each do |sub|
      subscribed |= is_subscribed_to?(sub)
    end
    return subscribed
  end

  # Determines if the member is subscribed to the given subscription.
  def is_subscribed_to?(subscription)
    member_sub = member_subscriptions.order(:updated_at).find_by(subscription: subscription)
    return member_sub.present? && member_sub.is_subscribed?
  end

  # Determines if the member is permanently unsubscribed.
  #
  # A member is considered to be permanently described if permanently
  # unsubscribed from all default subscriptions
  def unsubscribed_permanently?
    unsubscribed = !Subscription.defaults.empty?
    Subscription.defaults.each do |sub|
      unsubscribed &= is_unsubscribed_permanently_from?(sub)
    end
    return unsubscribed
  end

  # Determines if the member is permanently unsubscribed from the
  # given subscription.
  def is_unsubscribed_permanently_from?(subscription)
    ms = member_subscriptions.find_by(subscription: subscription)
    ms.present? && ms.unsubscribed_permanently?
  end

  # Subscribes member to all subscriptions marked as default
  def subscribe(reason: nil, event_time: DateTime.now, subscribable: nil)
    changed = false
    Subscription.defaults.each do |sub|
      if !is_subscribed_to?(sub)
        changed |= subscribe_to(
          sub, reason: reason, event_time: event_time, subscribable: subscribable
        )
      end
    end
    return changed
  end

  # Unsubscribes a member from all subscriptions
  def unsubscribe(reason: nil,
                  event_time: DateTime.now,
                  subscribable: nil,
                  unsub_mailing_id: nil,
                  permanent: false)
    changed = false

    if permanent
      # When permanently un-sub'ing, need to ensure all default subs
      # are permanently unsub'ed.
      Subscription.defaults do |sub|
        changed |= unsubscribe_from(
          sub,
          reason: reason,
          event_time: event_time,
          subscribable: subscribable,
          unsub_mailing_id: unsub_mailing_id,
          permanent: true
        )
      end
    end

    member_subscriptions.each.map do |member_sub|
      if member_sub.is_subscribed?
        changed |= unsubscribe_from(
          member_sub.subscription,
          reason: reason,
          event_time: event_time,
          subscribable: subscribable,
          unsub_mailing_id: unsub_mailing_id,
          permanent: permanent
        )
      end
    end

    return changed
  end

  def subscribe_to(subscription,
                   reason: nil,
                   event_time: DateTime.now,
                   subscribable: nil)
    return update_subscription(
      subscription,
      should_subscribe: true,
      event_time: event_time,
      operation_reason: reason,
      subscribable: subscribable
    )
  end

  def unsubscribe_from(subscription,
                       reason: nil,
                       event_time: DateTime.now,
                       subscribable: nil,
                       unsub_mailing_id: nil,
                       permanent: false)
    return update_subscription(
      subscription,
      should_subscribe: false,
      event_time: event_time,
      operation_reason: reason,
      subscribable: subscribable,
      unsub_mailing_id: unsub_mailing_id,
      permanent: permanent
    )
  end

  # Merge another member record with this member record
  def merge_other_records!(*other_members)
    transaction do
      # Write an audit
      self.audits << Audited::Audit.new({ action: 'merge', comment: { current_member: self.audits.as_json, other_members: other_members.map { |m| m.audits.as_json } }.to_json })

      ### Deal with special cases
      # Subscriptions: If either member is subbed to a subscription, then make the merge subbed
      subs = {}
      member_subs = other_members.map { |m| m.member_subscriptions }.flatten + self.member_subscriptions
      member_subs.each do |ms|
        # Once any ms.unsubscribed_at is not present, the value will remain true
        subs[ms.subscription_id] = subs[ms.subscription_id] || ms.unsubscribed_at.blank?
        ms.destroy!
      end

      reason = 'admin:merge_records'
      subs.each do |subscription_id, subbed|
        if subbed
          self.subscribe_to(Subscription.find(subscription_id), reason: reason)
        else
          self.unsubscribe_from(Subscription.find(subscription_id), reason: reason)
        end
      end

      # Delete area_memberships
      [self, *other_members].each { |m| m.areas.delete_all }

      # Call the catch-all merge method:
      self.merge!(*other_members)

      # update areas
      self.update_areas
    end
  end

  def self.irl
    joins(:actions).where(actions: { action_type: Action.irl_types })
  end

  def self.has_notes
    joins(:notes)
  end

  # Administration and account
  before_save :encrypt_password, if: :password_present
  before_save :generate_guid

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end

  def self.generate_password
    SecureRandom.urlsafe_base64(12).tr('lIO0', 'sxyz')
  end

  def generate_reset_token
    # Copied from Devise::friendly_token.
    # Generate a cryptographically secure random string 16 chars in lenght without
    # characters often confused.
    # TODO: Additionally encrypt this token too, since otherwise we're effectively
    # storing a password as plaintext
    SecureRandom.urlsafe_base64(12).tr('lIO0', 'sxyz')
  end

  def notify_made_admin
    signup_link = '<a href="' + Settings.app.app_url + '/register' + '">click here</a>'
    register_body = "Hi there,<br/><br/>You've been made an administrator on the #{Settings.app.org_title} Identity platform. Please complete your registration here: #{signup_link}.<br/><br/>Thanks,<br/>The #{Settings.app.org_title} team"

    Mailer::TransactionalMailWithDefaultReplyTo.send_email(
      from: "#{Settings.app.org_title} <#{AppSetting.emails.member_from_email}>",
      to: [email],
      subject: "#{Settings.app.org_title} - You've been made an administrator on Identity",
      body: register_body
    )
  end

  def email_member_data_export(email, password)
    data_archive_url = get_data_archive(password)

    @member = self

    default_path = Rails.root.join('gems/idlayout/app/views/idlayout/layouts/export.html.erb')
    org_path = Rails.root.join("gems/idlayout/app/views/idlayout/layouts/#{Settings.app.org_name}/export.html.erb")
    path = File.exist?(org_path) ? org_path : default_path
    template = File.read(path)

    message_content = ERB.new(template).result_with_hash(
      # These are the variables that are available in the exports template
      data_archive_url: data_archive_url,
      password: password,
    )

    Mailer::TransactionalMailWithDefaultReplyTo.send_email(
      to: [email],
      subject: 'Personal data request',
      body: message_content,
      from: "#{Settings.app.org_title} <#{AppSetting.emails.member_from_email}>",
      source: 'identity:member-data-json'
    )
  end

  def can_be_ghosted?
    Member.can_be_ghosted.where(id: self.id).exists?
  end

  def can_be_forcibly_ghosted?
    Member.can_be_forcibly_ghosted.where(id: self.id).exists?
  end

  def ghosting_started?
    anonymization_logs.any?
  end

  def ghosting_finished?
    anonymization_logs.where.not(anonymization_finished_at: nil).any?
  end

  def ghost_member(admin_member_id:, force: false)
    Ghoster.ghost_members_by_id(
      [self.id],
      reason: 'manual',
      admin_member_id: admin_member_id,
      force: force
    )

    true
  end

  def upsert_default_subscriptions(upsert_hash, _entry_point)
    if upsert_hash.key?(:subscriptions)
      passed_subscriptions = upsert_hash[:subscriptions].map do |sh|
        if (subscription = Subscription.find_by(id: sh[:id]) || Subscription.find_by(slug: sh[:slug]))
          subscription
        end
      end
    else
      passed_subscriptions = []
    end

    subscriptions_to_process = Subscription.defaults - passed_subscriptions
    subscriptions_to_process.each do |subscription|
      subscribe_to(subscription, reason: "default:opt_in")
    end
  end

  # metaclass methods
  class << self
    # import_from_csv is for importing members using the page on the Identity UI
    def import_from_csv(row, options = {})
      row = row.map { |key, value| [key.downcase, value] }.to_h

      member_hash = {
        emails: [{
                   email: row['email']
                 }],
        firstname: row['first_name'],
        middlenames: row['middle_names'],
        lastname: row['last_name']
      }

      phone_data = select_data(row, 'phone')

      unless phone_data.empty?
        phones = []
        phone_data.each do |_key, value|
          phones.push(phone: value)
        end
        member_hash[:phones] = phones
      end

      address_data = select_data(row, 'address_')
      unless address_data.empty?
        member_hash[:addresses] = [parse_data(address_data)]
      end

      %w(skill resource organisation).each do |w|
        named_attribute_data = select_data(row, w)
        unless named_attribute_data.empty?
          hash_key = "#{w}s".to_sym
          member_hash[hash_key] = []
          named_attribute_data.each do |_key, value|
            member_hash[hash_key] << { name: value }
          end
        end
      end

      custom_data = select_data(row, 'custom_')
      unless custom_data.empty?
        member_hash[:custom_fields] = parse_custom_data(custom_data)
      end

      member = UpsertMember.call(
        member_hash,
        entry_point: options.entry_point,
        new_member_opt_in: false # Allow import setttings to override the defaults
      )
      if options['create_subscriptions']
        member.subscribe(reason: 'admin:csv_import')
      end

      if options['add_to_list_id']
        ListMember.find_or_create_by!(member: member, list_id: options['list_id'])
      end

      member.id
    end

    # load_from_csv is for loading members from external services such as ControlShift
    # ControlShift has a nightly full data load, including old data, so can't just upsert everything
    def load_from_csv(row)
      payload = {
        emails: [{ email: row['email'] }],
        firstname: row['first_name'],
        lastname: row['last_name'],
        external_ids: { controlshift: row['id'] },
        updated_at: row['updated_at']
      }
      UpsertMember.call(payload)
    end

    def select_data(rows, key_name)
      rows.select do |key, value|
        key.start_with?(key_name) && value.present?
      end
    end

    def parse_data(rows)
      hash = {}
      rows.each do |key, value|
        key = key.split('_').last.to_sym
        hash[key] = value
      end
      hash
    end

    def parse_custom_data(rows)
      custom_fields = []
      rows.each do |key, value|
        key = key.split('_').last
        custom_fields.push({ name: key, value: value })
      end
      custom_fields
    end

    def record_action(payload, _route)
      # TODO: Post-May, we probably need a check BEFORE we store any personal info that
      # this person has either already consented to any required terms, OR the action
      # payload includes the relevant consent. If no consent is present, we COULD still
      # store this action, but without any personal data (eg. empty name, email, etc...)

      begin
        # find/create the member
        cons_hash = payload[:cons_hash].merge(updated_at: payload[:create_dt])
        ignore_names = Settings.options.ignore_name_change_for_donation && ['donate', 'regular_donate'].include?(payload[:action_type])
        member = UpsertMember.call(
          cons_hash,
          entry_point: "action:#{payload[:action_name]}",
          ignore_name_change: ignore_names
        )
        if member.present?
          # find/create the action
          begin
            query = { technical_type: payload[:action_technical_type],
                      external_id: payload[:external_id] }
            action = nil

            ### If no language specified in payload, find actions matching technical_type & external_id
            if payload[:language].nil?
              actions = Action.where(query)
              if actions.length == 1
                action = actions.first # if action only exists in a single language (or no language: legacy data)
              elsif actions.length > 1
                Rails.logger.error "The member action [member_id: #{member.id}, external_id: #{payload[:external_id]}, "\
                                   "technical_type: #{payload[:action_technical_type]}] contains no language code but"\
                                   "the action already exists in more than one language"

                # Still want to record an action, so first try to find a matching action with the default language
                action = actions.select { |a| a.language == AppSetting.actions.default_language }[0]
                # If 'action' is still nil here, then a new action with the default language will be created below
              end
            else
              # prefer searching for an (old) action with (explicitly) no language over creating a new (duplicate) one with a language
              action = Action.find_by(query.merge(language: payload[:language])) || Action.find_by(query.merge(language: nil))
            end

            # Create a new action if none found
            action = Action.create!(
              name: payload[:action_name],
              public_name: payload[:action_public_name],
              action_type: payload[:action_type],
              technical_type: payload[:action_technical_type],
              description: payload[:action_description] || '',
              external_id: payload[:external_id],
              language: payload[:language].presence || AppSetting.actions.default_language
            ) unless action
          rescue ActiveRecord::RecordNotUnique
            retry
          end

          # If the action's name has changed
          if payload[:action_name].present? && payload[:action_name] != action.name
            action.update!(name: payload[:action_name])
          end

          # If the action's public name has changed
          if payload[:action_public_name].present? && payload[:action_public_name] != action.public_name
            action.update!(public_name: payload[:action_public_name])
          end

          # Assign the controlshift campaign if one isn't set
          if !action.campaign && action.technical_type == 'cby_petition'
            campaign = Campaign.find_by(controlshift_campaign_id: action.external_id, campaign_type: 'controlshift')
            campaign.store_action_language(action.language) if campaign
            action.update!(campaign_id: campaign.id) if campaign
          end

          if payload[:campaign_id].present? && !action.campaign
            # Allow external actions to pass a known identity campaign id and link the action
            # to that campaign
            campaign = Campaign.find_by(id: payload[:campaign_id])
            campaign.store_action_language(action.language) if campaign
            action.update!(campaign_id: campaign.id) if campaign
          end

          # create member action
          if payload[:create_dt].presence.is_a? String
            created_at = ActiveSupport::TimeZone.new('UTC').parse(payload[:create_dt])
          else
            created_at = payload[:create_dt]
          end

          member_action = MemberAction.find_or_initialize_by(
            action_id: action.id,
            member_id: member.id,
            created_at: created_at
          )
          new_record = member_action.new_record?

          # subscribe the member to mailings
          # don't subscribe if disable_auto_subscribe is enabled (subscriptions must be handled through consents and post_consent_methods)
          # only if action is newer than his unsubscribe;
          # if opt_in is present, it must be set to true
          if !Settings.gdpr.disable_auto_subscribe && (payload[:opt_in].nil? || payload[:opt_in]) && !member.subscribed?
            email_subscription = member.member_subscriptions.find_by(subscription: Subscription::EMAIL_SUBSCRIPTION)
            if email_subscription.nil?
              member.subscribe
            elsif member_action.created_at > email_subscription.unsubscribed_at
              member.subscribe
            end
          end

          if member_action.valid? && payload[:source].present?
            # store utm codes against the action
            source_hash = payload[:source].slice(:source, :medium, :campaign).select { |_k, v| v.present? }

            if source_hash.present?
              source = Source.find_or_create_with_defaults(source_hash)

              # This *must* be an update in order to allow requests which update an old member action's source
              member_action.update!(source_id: source.id)
            end
          end

          if new_record && member_action.valid?
            # add consents to the member action
            if payload[:consents].present?
              payload[:consents].each do |consent_hash|
                next if consent_hash[:consent_level] == 'no_change' && !Settings.consent.record_no_change_consents

                consent_text = ConsentText.find_by!(public_id: consent_hash[:public_id])

                member_action.member_action_consents.build(
                  member_action: member_action,
                  consent_text: consent_text,
                  consent_level: consent_hash[:consent_level],
                  consent_method: consent_hash[:consent_method],
                  consent_method_option: consent_hash[:consent_method_option],
                  parent_member_action_consent: nil, # TODO: Something like `member.current_consents.find_by(consent_public_id: consent_text.public_id).member_action_consent` but only if it's a 'no_change'...
                  created_at: payload[:create_dt],
                  updated_at: payload[:create_dt]
                )
              end
            end

            ApplicationRecord.transaction do
              member_action.save!

              # split meta data into keys
              if payload[:metadata]
                payload[:metadata].each do |key, value|
                  # Get the key
                  action_key = ActionKey.find_or_create_by!(action: action, key: key.to_s)
                  # Allow nested data as metadata
                  if value.is_a?(Hash) || value.is_a?(Array)
                    value = value.to_json
                  end
                  MemberActionData.create!(
                    member_action_id: member_action.id,
                    action_key: action_key,
                    value: value
                  )
                end
              end

              # parse survey responses
              if payload[:survey_responses]
                payload[:survey_responses].each do |sr|
                  action_key = ActionKey.find_or_create_by!(action: action, key: sr[:question][:text])

                  Question.find_or_create_by! action_key: action_key do |q|
                    q.question_type = sr[:question][:qtype]
                  end

                  values = if sr[:answer].is_a? Array
                             sr[:answer]
                           else
                             [sr[:answer]]
                           end

                  values.each do |value|
                    MemberActionData.create!(
                      member_action_id: member_action.id,
                      action_key: action_key,
                      value: value
                    )
                  end
                end
              end

              # XXX old 38 data has nil created_at. Can't compare nil and date like this.
              if member.created_at.present? && member.created_at > member_action.created_at
                member.created_at = member_action.created_at
                member.save!
              end
            end
          else
            Rails.logger.info "Duplicate member action: action #{member_action.action_id} for member #{member_action.member_id}"
            return member_action
          end
        else
          Rails.logger.info "Failed to upsert member. Hash: #{payload.inspect}"
          return nil
        end
        return member_action
      rescue => e
        raise e
      end
    end

    # Takes a phone number and returns member or nil
    def find_by_phone(phone)
      PhoneNumber.find_by_phone(phone).try(:member)
    end

    def find_by_external_id(system, id)
      MemberExternalId.find_by(system: system, external_id: id).try(:member)
    end
  end

  # Blanking GUID so it will be regenerated in `before_save`
  def invalidate_guid!
    self.guid = ''
    self.save!
  end

  private

  TABULATE_CONFIG = {
    _root: {
      heading: 'Basic Details',
      fields: %w(title first_name middle_names last_name email mobile_phone gender created_at updated_at)
    },
    phone_numbers: %w(type phone updated_at),
    addresses: %w(line1 line2 town postcode country state updated_at),
    areas: %w(name area_type),
    demographic_groups: %w(demographic_class name),
    regular_donations: %w(started_at ended_at frequency medium source initial_amount current_amount amount_last_changed_at ended updated_at),
    donations: %w(amount medium external_source created_at),
    subscriptions: %w(subscription_type created_at unsubscribed_at unsubscribe_reason updated_at),
    subscription_logs: %w(operation unsubscribe_reason created_at),
    subscription_events: %w(operation operation_reason created_at),
    actions: %w(name action_type description source.source source.medium custom_data created_at),
    mailings_received: {
      heading: 'Emails Received',
      fields: %w(created_at subject first_opened first_clicked),
      sort_field: :created_at
    },
    sms_received: {
      heading: 'Text Messages',
      fields: %w(created_at body inbound from_number to_number status clicked_at),
      sort_field: :created_at
    },
    notifications_received: {
      heading: 'Push Notifications Received',
      fields: %w(created_at title opened),
      sort_field: :created_at
    },
    hosted_events: %w(name description location latitude longitude created_at),
    event_rsvps: %w(name created_at),
    notes: %w(note_type text created_at),
    custom_fields: %w(name data),
    groups: %w(name group_type membership_type),
    skills: %w(name updated_at),
    resources: %w(name updated_at),
    organisations: %w(name updated_at),
    audit_logs: :all,
    audits: %w(ip request_method path created_at),
    consents: {
      heading: 'GDPR Consents',
      fields: %w(consent_short_text consent_level consent_method consent_method_option created_at)
    },
    lists: {
      heading: 'Internal Lists',
      fields: %w(name created_at)
    }
  }.freeze

  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(password)
  end

  def password_present
    password.present?
  end

  def generate_guid
    self.guid = SecureRandom.hex(64) if guid.blank?
  end

  def get_data_archive(password)
    full_details, summary = generate_all_data

    zip_filename = "Data-Export-#{self.id}-#{Time.now.iso8601.to_s.delete(':')}.zip"

    zip_file = Zip::OutputStream.write_buffer(::StringIO.new(''), Zip::TraditionalEncrypter.new(password)) do |zip|
      zip.put_next_entry("Details_#{self.name.tr(' ', '_')[0..29]}.json")
      zip.write full_details.to_json
      zip.put_next_entry("Summary_#{self.name.tr(' ', '_')[0..29]}.txt")
      zip.write summary
    end.string

    # Upload to S3
    obj = S3_BUCKET.object("member-export/#{SecureRandom.hex(16)}/#{zip_filename}")
    obj.put(body: zip_file)

    obj.presigned_url(:get, expires_in: 3 * 24 * 60 * 60)
  end

  def generate_all_data
    member_data = self.as_json(except: [:id]).compact

    member_data[:phone_numbers] = self.phone_numbers.as_json(except: [:id, :member_id])

    member_data[:addresses] = self.addresses.as_json(except: [:id, :member_id]).map(&:compact)

    member_data[:areas] = self.areas.as_json(except: [:id, :member_id]).map(&:compact)

    member_data[:demographic_groups] = self.demographic_groups.as_json(except: [:id, :member_id])

    member_data[:regular_donations] = self.regular_donations.as_json(except: [:id, :member_id]).map(&:compact)

    member_data[:donations] = self.donations.as_json(except: [:id, :member_id]).map(&:compact)

    member_data[:subscriptions] = self.member_subscriptions.as_json(except: [:id, :member_id]).map do |sub|
      sub[:subscription_type] = Subscription.find(sub["subscription_id"]).name
      sub.as_json(except: ["subscription_id"]).compact
    end

    # Old subscription tracking that has been removed from identity
    subscription_logs = ActiveRecord::Base.connection.exec_query("SELECT operation, unsubscribe_reason, created_at FROM member_subscription_logs WHERE member_id = #{self.id}")
    member_data[:subscription_logs] = subscription_logs.to_a

    # New subscription tracking
    member_data[:subscription_events] = self.member_subscription_events
                                            .as_json(only: [:operation, :operation_reason, :created_at])
                                            .map(&:compact)

    member_data[:actions] = self.member_actions.as_json(except: [:member_id]).map do |member_action|
      action = Action.find(member_action["action_id"])
      member_action[:name] = action.name
      member_action[:description] = action.description
      member_action[:action_type] = action.action_type

      source = Source.find(member_action["source_id"]) if member_action["source_id"]
      if source
        member_action[:source] = {
          campaign: source.campaign,
          medium: source.medium,
          source: source.source
        }.compact
      end

      action_data = MemberActionData.where(member_action_id: member_action["id"])
      if action_data
        custom_data = action_data.map do |ad|
          {
            type: ad.action_key.key,
            value: ad.value,
            created_at: ad.created_at
          } unless ad.value.nil?
        end
        member_action[:custom_data] = custom_data.compact
      end

      member_action.as_json(except: ["id", "action_id", "source_id"]).compact
    end

    member_data[:mailings_received] = self.member_mailings.map do |mm|
      member_mailing = mm

      mm = mm.as_json(except: [:id, :member_id, :mailing_variation_id, :mailing_id])
      mm[:name] = member_mailing.mailing.name
      mm[:subject] = member_mailing.mailing.subject
      mm[:first_opened] = member_mailing.first_opened
      mm[:first_clicked] = member_mailing.first_clicked

      mm[:opens] = member_mailing.opens.map do |open|
        {
          opened_at: open.created_at,
          ip: open.ip_address,
          user_agent: open.user_agent
        }.compact
      end

      mm[:clicks] = member_mailing.clicks.map do |click|
        {
          clicked_at: click.created_at,
          ip: click.ip_address,
          user_agent: click.user_agent,
          link: click.mailing_link.try(:url)
        }.compact
      end

      mm.as_json.compact.reject { |_, v| v.is_a?(Array) && v.empty? }
    end

    member_data[:sms_received] = self.smses.as_json(except: [:id, :member_id]).map(&:compact)

    member_data[:notifications_received] = self.member_notifications.as_json(except: [:id, :member_id]).map(&:compact)

    member_data[:hosted_events] = self.hosted_events.as_json(except: [:id, :host_id, :external_id]).map(&:compact)

    member_data[:event_rsvps] = self.event_rsvps.as_json(except: [:id, :member_id]).map do |rsvp|
      rsvp[:name] = Event.find(rsvp['event_id']).name
      rsvp.as_json(except: ['event_id']).compact
    end

    member_data[:notes] = self.notes.as_json(except: [:id, :member_id, :user_id]).map do |note|
      note[:note_type] = NoteType.find(note['note_type_id']).name
      note.as_json(except: ['note_type_id']).compact
    end

    member_data[:custom_fields] = self.custom_fields.as_json(except: [:id, :member_id]).map do |cf|
      cf[:name] = CustomFieldKey.find(cf['custom_field_key_id']).name
      cf.as_json(except: ['custom_field_key_id']).compact
    end

    member_data[:groups] = self.group_members.as_json(except: [:id, :member_id]).map do |group_member|
      group = Group.find(group_member["group_id"])
      group_member[:name] = group.name
      group_member[:group_type] = group.group_type
      group_member.as_json(except: [:group_id]).compact
    end

    member_data[:skills] = self.member_skills.as_json(except: [:id, :member_id]).map do |member_skill|
      member_skill[:name] = Skill.find(member_skill["skill_id"]).name
      member_skill.as_json(except: ["skill_id"]).compact
    end

    member_data[:resources] = self.member_resources.as_json(except: [:id, :member_id]).map do |member_resource|
      member_resource[:name] = Resource.find(member_resource['resource_id']).name
      member_resource.as_json(except: ['resource_id']).compact
    end

    member_data[:organisations] = self.organisation_memberships.as_json(except: [:id, :member_id]).map do |membership|
      membership[:name] = Organisation.find(membership['organisation_id']).name
      membership.as_json(except: ['organisation_id']).compact
    end

    audit_logs = (self.audits + self.associated_audits).map do |audit|
      audit_log = {
        type: audit.action,
        changes: audit.audited_changes.compact,
        remote_address: audit.remote_address,
        created_at: audit.created_at
      }.as_json.compact

      audit.audited_changes.empty? ? {} : audit_log
    end
    member_data[:audit_logs] = audit_logs.reject { |audit_log| audit_log.empty? }

    member_data[:consents] = self.member_action_consents.as_json(except: [:id, :member_action_id]).map do |mac|
      mac[:text] = ConsentText.find(mac["consent_text_id"]).consent_short_text

      mac.as_json.compact
    end

    if Settings.member_data_export.export_lists
      member_data[:lists] = self.lists.as_json(except: [:id, :synced_to_redshift, :member_count]).map(&:compact)
    end

    member_data = member_data.compact.reject { |_, v| v.is_a?(Array) && v.empty? }

    member_summary = tabulate_all(
      member_data,
      TABULATE_CONFIG
    )

    [member_data, member_summary]
  end

  # update_subscription is intended to be a single method to update subscriptions,
  # which correctly handles old updates by checking the sub/unsub event is newer
  # than the last time the subscription was updated before processing.
  # Returns true if the subscription was updated, false if not (ie. old event)
  def update_subscription(subscription,
                          should_subscribe:,
                          event_time:,
                          operation_reason: nil,
                          subscribable: nil,
                          unsub_mailing_id: nil,
                          permanent: false)
    retried = false
    begin
      ms = self.member_subscriptions.find_or_initialize_by(subscription: subscription) do |member_sub|
        # Ensure new records have the time of this event
        member_sub.created_at = event_time
        member_sub.updated_at = event_time
      end

      # Ensure record has attributes against subscribable and operation_reason
      ms.subscribable = subscribable
      ms.operation_reason = operation_reason

      # Only process this event if it's newer than the previous sub/unsub event or it's a new subscription
      if event_time > ms.updated_at || ms.new_record?
        if unsubscribed_permanently?
          return ms.update!(
            subscribed_at: nil,
            subscribe_reason: nil,
            unsubscribed_at: event_time,
            unsubscribe_reason: 'Deferred as permanently unsubscribed',
            updated_at: event_time,
            permanent: true
          )
        elsif ms.unsubscribed_permanently?
          return ms.update!(
            subscribed_at: nil,
            subscribe_reason: nil,
            unsubscribed_at: event_time,
            unsubscribe_reason: 'Deferred as permanently unsubscribed from subscription',
            updated_at: event_time,
            permanent: true
          )
        elsif should_subscribe
          return ms.update!(
            subscribed_at: event_time,
            subscribe_reason: (operation_reason || 'not specified'),
            unsubscribed_at: nil,
            unsubscribe_reason: nil,
            updated_at: event_time
          )
        elsif !should_subscribe
          return ms.update!(
            subscribed_at: nil,
            subscribe_reason: nil,
            unsubscribed_at: event_time,
            unsubscribe_reason: (operation_reason || 'not specified'),
            unsubscribe_mailing_id: unsub_mailing_id,
            updated_at: event_time,
            permanent: permanent
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
end
