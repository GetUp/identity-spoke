# == Schema Information
#
# Table name: lists
#
#  id           :integer          not null, primary key
#  name         :text
#  created_at   :datetime
#  updated_at   :datetime
#  member_count :integer
#  permanent    :boolean, not null, default false
#

require 'csv'

class List < ApplicationRecord
  include Orderable
  include Searchable

  has_many :list_members, dependent: :destroy
  has_many :members, through: :list_members
  has_many :mailings, dependent: :nullify, class_name: 'Mailings::Mailing'
  has_many :notifications, dependent: :nullify, class_name: 'WebNotifications::Notification'
  has_many :text_blasts, dependent: :nullify, class_name: 'TextBlasts::TextBlast'
  has_many :syncs

  belongs_to :search
  belongs_to :author, class_name: 'Member'
  validates_presence_of :name

  serialize :criteria

  API_FIELDS = %w(id name search_id member_count permanent author_id updated_at).freeze

  class AnonymizationError
    class TooLarge < StandardError
      def message
        "List has too many list_members to ghost"
      end
    end

    class WrongName < StandardError
      def message
        "List names must begin with 'ghost'"
      end
    end
  end

  def self.name_contains(search)
    search_sql = Arel.sql("%#{sanitize_sql_like(search)}%")
    order_sql = Arel.sql("#{ApplicationRecord.connection.quote_table_name(Settings.databases.extensions_schemas.core)}.similarity(name, ?)")
    order_sql = Arel.sql(sanitize_sql_for_order([order_sql, search]))
    where('name ILIKE ?', search_sql).order(order_sql)
  end

  def count_members
    update!(member_count: list_members.count)
  end

  def safe_to_ghost?(max_members: Settings.ghoster.bulk_max_members)
    check_safe_to_ghost!(max_members: max_members)
    return true
  rescue List::AnonymizationError::TooLarge
    return false
  rescue List::AnonymizationError::WrongName
    return false
  end

  def check_safe_to_ghost!(max_members: Settings.ghoster.bulk_max_members)
    raise List::AnonymizationError::TooLarge unless member_count <= max_members
    raise List::AnonymizationError::WrongName unless name.downcase.start_with?('ghost')
  end

  def generate_csv_with_fields(fields, subscription_id = nil, custom_field_key_ids = [])
    status_name = "Generate CSV for list ##{id} '#{self.name}'"
    JobStatus.report(status_name)

    subscription_select = subscription_join = custom_field_select = custom_field_joins = ''

    if subscription_id.present?
      subscription_id = Subscription.find_by(id: subscription_id)&.id # avoid SQLi

      if subscription_id.present?
        fields << 'subscription_status'
        subscription_select = ", (CASE when ms.id is not null and ms.unsubscribed_at is null THEN 'subscribed' ELSE 'not subscribed' END) as subscription_status"
        subscription_join = "LEFT JOIN member_subscriptions ms ON ms.member_id = lm.member_id AND ms.subscription_id = #{subscription_id}"
      end
    end

    if custom_field_key_ids.count.positive?
      custom_field_key_ids = CustomFieldKey.where(id: custom_field_key_ids).pluck(:id)
      fields.concat(custom_field_key_ids.map { |id| "custom_field_#{id}" })
      custom_field_select = custom_field_key_ids.map { |id| ", cf#{id}.data as custom_field_#{id}" }.join('')
      custom_field_joins = custom_field_key_ids.map do |id|
        <<~SQL
          LEFT JOIN custom_fields cf#{id}
            ON cf#{id}.member_id = lm.member_id AND cf#{id}.custom_field_key_id = #{id}
        SQL
      end.join(' ')
    end
    fields = fields.map { |f| f.to_s }
    file_string = CSV.generate do |csv|
      csv << fields
      batch_number = 0
      loop do
        JobStatus.report(status_name, message: 'Writing batch #' + batch_number.to_s, progress: (100 * batch_number * 1000 / self.member_count.to_f))
        rows = ApplicationRecord.connection.execute(
          <<~SQL
            SELECT DISTINCT ON (m.id) first_name, middle_names, last_name, phone, email, line1, line2, town, state, postcode, country #{subscription_select} #{custom_field_select}
            FROM members m
            JOIN list_members lm
              ON lm.member_id = m.id
            LEFT JOIN phone_numbers pn
              ON pn.member_id = lm.member_id
            LEFT JOIN addresses a
              ON a.member_id = lm.member_id
            #{subscription_join}
            #{custom_field_joins}
            WHERE lm.list_id = #{self.id}
            ORDER BY m.id, pn.updated_at DESC, a.updated_at DESC
            LIMIT 1000
            OFFSET #{1000 * batch_number}
          SQL
        )
        break unless rows.any?

        rows.each { |row| csv << row.slice(*fields).values }
        batch_number += 1
      end
    end

    JobStatus.report(status_name, finished: true)
    return file_string
  end

  def email_fields(email, password, fields, subscription_id = nil, custom_field_key_ids = [])
    file_string = generate_csv_with_fields(fields, subscription_id, custom_field_key_ids)

    # Zip up results
    zip_filename = "List-#{self.id}-#{Time.now.iso8601.to_s.delete(':')}.zip"

    zip_file = Zip::OutputStream.write_buffer(::StringIO.new(''), Zip::TraditionalEncrypter.new(password)) do |zip|
      zip.put_next_entry("#{self.name.tr(' ', '_')[0..29]}.csv")
      zip.write file_string
    end.string

    # Upload to S3
    obj = S3_BUCKET.object("lists/#{SecureRandom.hex(16)}/#{zip_filename}")
    obj.put(body: zip_file)

    message_content = "Your list is here: #{obj.presigned_url(:get, expires_in: 24 * 60 * 60)}<br><br>This link will be valid for one day!"

    Mailer::TransactionalMailWithDefaultReplyTo.send_email(
      to: [email],
      subject: "Member List export of '#{self.name}'",
      body: message_content,
      from: "#{Settings.app.org_title} <#{AppSetting.emails.admin_from_email}>",
      source: 'identity:email-csv'
    )
  end

  def check_redshift_sync
    redshift_member_count = RedshiftDB.connection.execute("SELECT COUNT(*) as count FROM list_members WHERE list_id = #{id}").first['count'].to_i
    if redshift_member_count == member_count
      update!(synced_to_redshift: true)
    end
  end

  def copy_to_redshift
    if Settings.options.use_redshift
      RedshiftDB.connection.execute("DELETE FROM list_members WHERE list_id = #{self.id}")
      list_members.find_in_batches(batch_size: 10_000) do |slice|
        value_strings = []
        slice.each do |list_member|
          value_strings << ApplicationRecord.sanitize_sql_for_assignment(["(?,?,?,GETDATE(),GETDATE())", list_member.id, id, list_member.member_id])
        end
        begin
          RedshiftDB.connection.execute("INSERT INTO list_members (id,list_id,member_id,created_at,updated_at) VALUES #{value_strings.join(',')}")
        rescue
          RedshiftDB.connection.execute("DELETE FROM list_members WHERE list_id = #{self.id}")
          raise
        ensure
          GC.start
        end
      end
    end
    update!(synced_to_redshift: true)
  end

  def add_new_member(member)
    ListMember.find_or_create_by!(list_id: id, member: member)
    CountListMembersWorker.perform_async(id)
  end

  def push_to_conditional(*)
    conditional_list = ConditionalList.find_or_create_by!(name: self.name)
    ConditionalList.connection.execute <<~SQL
      INSERT INTO conditional_list_members (member_id, conditional_list_id, created_at, updated_at)
      (
        SELECT member_id, #{conditional_list.id}, current_timestamp, current_timestamp
        FROM list_members WHERE list_id = #{self.id}
      )
    SQL

    ConditionalList.reset_counters(conditional_list.id, :members)
  end

  def to_hash_for_api
    as_json.slice(*API_FIELDS)
  end

  class << self
    def ordered_by_desc
      order('updated_at DESC')
    end

    def synced_to_redshift
      if Settings.options.use_redshift
        where(synced_to_redshift: true)
      else
        all
      end
    end

    def make_new_from_human_input_member_ids(name, member_ids, permanent:, author_id:, callback_url: nil)
      member_ids.map!(&:to_i)
      # This prevents ActiveRecord::ForeignKeyInvalid errors when humans input
      # bad member_ids
      member_ids = Member.where(id: member_ids).pluck(:id)
      make_new_from_member_ids(name, member_ids, permanent: permanent, callback_url: callback_url, author_id: author_id)
    end

    def make_new_from_emails(name, emails, permanent:, author_id:, callback_url: nil)
      emails.map!(&:strip).map!(&:downcase)
      member_ids = Member.where(email: emails).pluck(:id)
      make_new_from_member_ids(name, member_ids, permanent: permanent, callback_url: callback_url, author_id: author_id)
    end

    def make_new_from_guids(name, guids, permanent:, author_id:, callback_url: nil)
      guids.map!(&:strip)
      member_ids = Member.where(guid: guids).pluck(:id)
      make_new_from_member_ids(name, member_ids, permanent: permanent, callback_url: callback_url, author_id: author_id)
    end

    def make_new_from_phones(name, phones, permanent:, author_id:, callback_url: nil)
      clean_numbers = phones.map do |pn|
        PhoneNumber.standardise_phone_number(pn)
      end.select do |pn|
        pn.present?
      end

      member_ids = PhoneNumber.where(phone: clean_numbers).pluck(:member_id)
      make_new_from_member_ids(name, member_ids, permanent: permanent, callback_url: callback_url, author_id: author_id)
    end

    # member_ids_sql must select the member id in a column aliased 'member_id'
    # Make sure that it is safe from sql injection - i.e. no unquoted user input.
    # The responsiblity for this is on the caller!
    def make_new_from_sql(name, member_ids_sql, permanent:, author_id:, callback_url: nil)
      member_ids = ApplicationRecord.connection.execute(member_ids_sql).column_values(0)
      make_new_from_member_ids(name, member_ids, permanent: permanent, author_id: author_id, callback_url: callback_url)
    end

    def make_new_from_member_ids(name, member_ids, permanent:, author_id:, callback_url: nil)
      # Note: All members ids passed must exist in the members table.
      # If invalid member ids are passed it will raise ActiveRecord::InvalidForeignKey
      list = List.create!(name: name, permanent: permanent, author_id: author_id)

      member_ids.each_slice(10_000) do |member_ids_slice|
        begin
          ActiveRecord::Base.connection.raw_connection.exec(
            'INSERT INTO list_members (list_id, member_id, created_at, updated_at)
            SELECT $1, member_id, current_timestamp, current_timestamp FROM unnest($2 ::int[]) member_id',
            [list.id, PG::TextEncoder::Array.new.encode(member_ids_slice)]
          )
        rescue
          list.destroy!
          raise
        ensure
          GC.start
        end
      end

      list.copy_to_redshift

      if callback_url.present?
        GenericJsonClient.post(callback_url, { success: true, list_id: list.id })
      end

      list.count_members

      list
    end
  end
end
