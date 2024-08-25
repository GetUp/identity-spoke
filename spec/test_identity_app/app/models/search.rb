# == Schema Information
#
# Table name: searches
#
#  id            :integer          not null, primary key
#  created_at    :datetime
#  updated_at    :datetime
#  name          :text
#  complete      :boolean
#  member_ids    :text
#  total_members :integer
#  offset        :integer
#  count         :integer
#  page          :integer
#  rules         :text
#  permanent     :boolean, not null, default false
#  description   :text
#

class Search < ApplicationRecord
  include Orderable
  include Searchable

  has_many :lists, dependent: :nullify
  has_many :syncs, :through => :lists
  has_many :flows
  belongs_to :author, class_name: 'Member'

  self.table_name = 'searches'
  serialize :rules
  validate :test_run, if: :rules_changed?
  validates :name, presence: true

  scope :with_pinned, -> {
    where(pinned: true)
  }

  # This little oddity is so that the SQL is available to other apps without them having to have the full Search class
  after_save :save_sql

  API_UPDATE_FIELDS = %w(name permanent rules).freeze

  # rubocop:disable Rails/SkipsModelValidations
  def save_sql
    update_column(:sql, to_sql) if rules
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Test the SQL against the database so we can surface errors to user
  def test_run
    return unless rules

    test_sql = "EXPLAIN #{to_sql}"
    RedshiftDB.connection.execute(test_sql)
  rescue ActiveRecord::StatementInvalid => e
    errors.add(:sql, e.message)
  end

  def include_rules
    if rules.is_a?(Hash)
      rules['include']
    else
      if AppSetting.searches.default_search_id == 'none'
        { 'condition' => 'AND', 'rules' => [{ 'id' => 'everyone', 'field' => 'everyone', 'type' => 'string', 'operator' => 'equal', 'value' => 'on' }] }
      else
        Search.find(AppSetting.searches.default_search_id).rules['include']
      end
    end
  end

  def set_mailing_include_rule(type:, mailing_id: nil)
    new_rules = [{ "id" => "subscribed", "field" => "subscribed", "type" => "string", "operator" => "equal", "value" => "on" }]

    if mailing_id
      new_rules.push({ "id" => type, "field" => type, "type" => "integer", "input" => "select", "operator" => "in", "value" => [mailing_id] })
    end
    new_include = { 'condition' => 'AND', 'rules' => new_rules }

    update!(rules: (rules || { 'exclude' => exclude_rules }).merge('include' => new_include))
  end

  def set_mailing_exclude_rule(type:, mailing_id:)
    new_exclude = { 'condition' => 'OR', 'rules' => [{ "id" => type, "field" => type, "type" => "integer", "input" => "select", "operator" => "in", "value" => [mailing_id] }] }

    update!(rules: (rules || { 'include' => include_rules }).merge('exclude' => new_exclude))
  end

  def exclude_rules
    if rules.is_a?(Hash)
      rules['exclude']
    else
      if AppSetting.searches.default_search_id == 'none'
        { 'condition' => 'OR', 'rules' => [{ 'id' => 'noone', 'field' => 'noone', 'type' => 'string', 'operator' => 'equal', 'value' => 'on' }] }
      else
        Search.find(AppSetting.searches.default_search_id).rules['exclude']
      end
    end
  end

  def count_members
    RedshiftDB.connection.execute("SELECT COUNT(*) as count FROM members m WHERE #{ApplicationRecord.sanitize_sql(to_sql_conditions)}").first['count'].to_i
  end

  def get_sample_member_ids(sample_divider, callback_url = nil)
    sample_member_ids = RedshiftDB.connection.raw_connection.async_exec(%Q{SELECT id FROM (#{sql}) t WHERE id % #{sample_divider} = 0}).column_values(0).map(&:to_i)
    total_count = RedshiftDB.connection.raw_connection.async_exec(%Q{SELECT count(*) FROM (#{sql}) t}).column_values(0).first.to_i

    if callback_url.present?
      GenericJsonClient.post(callback_url, { sample_member_ids: sample_member_ids, total_count: total_count })
    end

    return sample_member_ids
  end

  def job_status_name(list_name)
    "Push Search ##{id}: '#{self.name}' to list '#{list_name}'"
  end

  def push_to_list(name, services: [], limit: 0, split_count: 1, permanent: false, list_author_id: nil, callback_url: nil)
    status_name = job_status_name(name)
    JobStatus.report(status_name)

    limit = limit.to_i
    split_count = [1, split_count.to_i].max

    if limit == 0
      sql = Member.from('members m').where(to_sql_conditions).select('m.id').to_sql
    else
      sql = Member.from('members m').where(to_sql_conditions).order('RANDOM()').limit(limit).select('m.id').to_sql
    end

    JobStatus.report(status_name, message: 'Running SQL')
    member_ids = RedshiftDB.connection.raw_connection.async_exec(sql).column_values(0)
    total_count = member_ids.count
    JobStatus.report(status_name, message: "Writing list to database (#{total_count} members)")

    # using new_lists allows us to only push the lates lists to conditional lists and external services
    # not all lists attached to the search
    new_lists = member_ids.in_groups(split_count, false).map.with_index do |ids, index|
      list_name = split_count > 1 ? "#{name} #{index + 1}/#{split_count}" : name

      list = List.make_new_from_member_ids(list_name, ids, permanent: permanent, author_id: list_author_id)
      list.update!(search_id: id)

      JobStatus.report(status_name, progress: ((index + 1) / split_count.to_f) * 80)

      list
    end

    ConditionalList.initialize_from_lists(new_lists) unless services.filter_map { |service| service if service['service'] == 'conditional' }.empty?

    sanitized_services_for_sync = services.filter_map { |service| service unless service['service'] == 'conditional' }
    Sync.initialise_pushes_from_list_creation(new_lists, sanitized_services_for_sync, list_author_id)

    JobStatus.report(status_name, finished: true)

    if callback_url.present?
      GenericJsonClient.post(callback_url, { lists: new_lists.map(&:to_hash_for_api) })
    end

    lists
  end

  def member_tags_update(tag_type, tag_id, remove)
    batch_size = 1000
    status_name = "Add tags to search ##{id} members"
    JobStatus.report(status_name)
    is_org = tag_type.to_s === 'organisation'

    tag_map = {
      :organisation => 'OrganisationMembership',
      :skill => 'MemberSkill',
      :resource => 'MemberResource'
    }

    sql = Member.from('members m').where(to_sql_conditions).select('m.email, m.id').to_sql
    result = RedshiftDB.connection.execute(sql)
    ids = result.pluck 'id'

    JobStatus.report(status_name, progress: 0,
                                  message: "#{remove ? 'Removing' : 'Adding'} #{tag_type.to_s.pluralize} #{remove ? 'from' : 'to'} members")

    conditions = { member_id: ids }
    conditions[(tag_type.to_s + '_id').to_sym] = tag_id
    Object.const_get(tag_map[tag_type.to_sym]).where(ApplicationRecord.sanitize_sql_for_conditions(conditions)).destroy_all
    unless remove
      value_strings = ids.map do |id|
        ApplicationRecord.sanitize_sql_for_assignment(["(?, ?, current_timestamp, current_timestamp)", id, tag_id])
      end
      idx = 0
      value_strings.each_slice(batch_size) do |slice|
        ApplicationRecord.transaction do
          db_table = ApplicationRecord.connection.quote_table_name("#{is_org ? 'organisation_membership' : 'member_' + tag_type}s")
          tag_column = ApplicationRecord.connection.quote_column_name("#{tag_type}_id")
          ApplicationRecord.connection.execute(
            <<~SQL
              INSERT INTO #{db_table} (member_id, #{tag_column}, created_at, updated_at)
              VALUES #{(slice.join(','))}
            SQL
          )
        end
        idx += 1
        JobStatus.report(status_name, progress: 100 * idx / value_strings.length / batch_size,
                                      message: "Batch updating members tags...")
      end
    end

    JobStatus.report(status_name, finished: true)
  end

  def member_custom_fields_update(custom_field_key_id, data, remove)
    batch_size = 1000
    status_name = "Add custom fields to search ##{id} members"
    JobStatus.report(status_name)

    sql = Member.from('members m').where(to_sql_conditions).select('m.email, m.id').to_sql
    result = RedshiftDB.connection.execute(sql)
    ids = result.pluck 'id'

    JobStatus.report(status_name, progress: 0,
                                  message: "#{remove ? 'Removing' : 'Adding'} custom fields #{remove ? 'from' : 'to'} members")

    if remove
      conditions = { member_id: ids, custom_field_key_id: custom_field_key_id, data: data }
      CustomField.where(conditions).in_batches(of: 1000).destroy_all
    end

    unless remove
      value_strings = ids.map do |id|
        ApplicationRecord.sanitize_sql_for_assignment(["(?, ?, ?, current_timestamp, current_timestamp)", id, custom_field_key_id, data])
      end
      idx = 0
      value_strings.each_slice(batch_size) do |slice|
        ApplicationRecord.transaction do
          ApplicationRecord.connection.execute(
            "INSERT INTO custom_fields (member_id, custom_field_key_id, data, created_at, updated_at)
              VALUES #{slice.join(',')}"
          )
        end
        idx += 1
        JobStatus.report(status_name, progress: 100 * idx / value_strings.length / batch_size,
                                      message: "Batch updating members custom fields...")
      end
    end

    JobStatus.report(status_name, finished: true)
  end

  def member_event_rsvps(event_id)
    status_name = "Creates event rsvps to search ##{id} members"
    JobStatus.report(status_name)

    sql = Member.from('members m').where(to_sql_conditions).select('m.id').to_sql
    result = RedshiftDB.connection.execute(sql)
    ids = result.pluck 'id'
    JobStatus.report(status_name, progress: 0,
                                  message: "Creating Event RSVPs for members")

    event_rsvp_base = {
      event: { id: event_id },
      data: { system: 'identity' }
    }
    idx = 0
    ids.each do |id|
      EventRsvp.create_rsvp(event_rsvp_base.merge(rsvp: { member_id: id }))
      idx += 1
      JobStatus.report(status_name, progress: 100 * idx / ids.length,
                                    message: "Creating event rsvps for members...")
    end
    JobStatus.report(status_name, finished: true)
  end

  ### SQL generation methods

  def to_sql_conditions
    nested_sql = rules_to_sql(include_rules.deep_dup)
    sql_include = Search.flatten_nested_sql(nested_sql)

    nested_sql = rules_to_sql(exclude_rules.deep_dup)
    sql_exclude = Search.flatten_nested_sql(nested_sql)

    "m.id IN (#{sql_include} EXCEPT #{sql_exclude})"
  end

  def to_sql
    "SELECT id FROM members m WHERE #{to_sql_conditions}"
  end

  def self.flatten_nested_sql(nested_sql)
    if nested_sql.is_a?(Hash)

      # Because we're working with arrays of integers,
      # using UNION, INTERSECT and EXCEPT will result in
      # postgres executing the queries more efficiently.
      # If one uses multiple WHERE INs, with ANDs, ORs and NOTs,
      # the pg query planner might execute the query using a
      # nested loop that runs forever. Previously this was
      # mitigated by moving to an expensive analytics db that
      # could handle those queries, like aws redshift.
      condition = case nested_sql['condition']
                  when 'OR'
                    'UNION'
                  when 'AND'
                    'INTERSECT'
                  else
                    raise "Unsupported condition: '#{condition}'"
                  end

      '(' + nested_sql['rules'].map { |rule|
        Search.flatten_nested_sql(rule)
      }.join(" #{condition} ") + ')'
    else
      nested_sql
    end
  end

  def rules_to_sql(nested_hash)
    # if has key "condition" then this is itself a set of rules, so recurse!
    if nested_hash.is_a?(Array)
      nested_hash.map! do |hash|
        rules_to_sql(hash)
      end
    elsif nested_hash['condition']
      nested_hash['rules'] = rules_to_sql(nested_hash['rules'])
    elsif nested_hash.is_a?(Hash)
      nested_hash = rule_to_sql(nested_hash)
    end
    nested_hash
  end

  def rule_to_sql(rule)
    @filters = Search.filters unless @filters
    filter = @filters.find { |x| x[:id] == rule['id'] }

    if filter.key? :sql
      sql = filter[:sql]

      if rule['value'].is_a?(Array)
        value = rule['value'].map { |x| ApplicationRecord.connection.quote(x) }.join(',')
      elsif rule['value'].is_a?(String) && %w[contains not_contains].include?(rule['operator'])
        value = ApplicationRecord.connection.quote('%' + rule['value'] + '%')
      elsif rule['id'] == 'sql'
        value = rule['value']
      else
        value = ApplicationRecord.connection.quote(rule['value'])
      end

      sql = sql.gsub('%%QUOTED_VALUE%%', value)
      sql = sql.gsub('%%RAW_VALUE%%', value)
      sql = sql.gsub('%%UNQUOTED_INTS%%', value.delete("'"))
    elsif filter.key? :lambda
      sql = filter[:lambda].call(rule)
    end

    sql = "(#{sql})"

    # Use EXCEPT to handle inverted queries
    if %w[not_equal not_contains not_in not_between not_begins_with not_ends_with].include?(rule['operator'])
      sql = "(SELECT id AS member_id FROM members EXCEPT #{sql})"
    end

    sql
  end

  ### Definitions of different types of searches and search crteria
  def self.sorts
    {
      'default' => ['-- No sorting --', '', ''],
      'name-az' => ['Name (A-Z)', 'name asc', ''],
      'name-za' => ['Name (Z-A)', 'name desc', ''],
      'membership-l' => ['Membership length (longest first)', 'members.created_at asc', ''],
      'membership-s' => ['Membership length (shortest first)', 'members.created_at desc', ''],
      'donations-hl' => ['Number of donations (Most first)', 'members.donations_count desc', ''],
      'donations-lh' => ['Number of donations (Least first)', 'members.donations_count asc', '']
    }
  end

  # TODO: searchable_action_types appears to be unused, but if we did then look at using the Settings.actions section...
  def self.searchable_action_types
    [
      %w[Call call],
      ['Donation', 'donate|donation'],
      %w[Facebook facebook],
      ['IRL', 'rsvp|flyering|register_voters_offline'],
      %w[Petition petition],
      %w[RSVP rsvp],
      %w[Speakout speakout],
      %w[Share share],
      ['Survey', 'survey|poll'],
      %w[Tweet tweet]
    ]
  end

  def self.add_filter_group filter_group_class
    raise "Filter group module with name '#{filter_group_class.name}' must implement class method 'filters'" unless (
      filter_group_class.respond_to? :filters
    )

    @@filters.push(*filter_group_class.filters)
  end

  def self.initialize_filters
    @@filters = []

    add_filter_group SearchFilters::Basic
    add_filter_group SearchFilters::Actions
    add_filter_group SearchFilters::CirclesOfEngagement
    add_filter_group SearchFilters::Donations
    add_filter_group SearchFilters::Demographics
    add_filter_group SearchFilters::DropOffs
    add_filter_group SearchFilters::Geography
    add_filter_group SearchFilters::People
    add_filter_group SearchFilters::IRL
    add_filter_group SearchFilters::Notes
    add_filter_group SearchFilters::Mailings
    add_filter_group SearchFilters::Contacts
    add_filter_group SearchFilters::Advanced
    add_filter_group SearchFilters::ExternalSystem
    add_filter_group SearchFilters::Events
    add_filter_group SearchFilters::Searches
    add_filter_group SearchFilters::Subscriptions
  end

  initialize_filters

  def self.filters
    filters = @@filters.deep_dup

    # TODO: Delete these mosaic filters - mosaic columns on member are deprecated, and the new demographic_groups should be used
    if Settings.options.use_mosaic
      # mosaic group filter
      filters << {
        optgroup: 'Demographics',
        id: 'mosaic-group',
        label: 'In MOSAIC groups (DEPRECATED)',
        operators: %w[in not_in],
        type: 'string',
        sql: "SELECT id FROM members WHERE mosaic_group IN (%%QUOTED_VALUE%%)",
        values: ("A".."O").to_a,
        input: 'checkbox',
        multiple: true
      }

      # mosaic type filter
      filters << {
        optgroup: 'Demographics',
        id: 'mosaic-type',
        label: 'In MOSAIC types (DEPRECATED)',
        operators: %w[in not_in],
        type: 'integer',
        sql: 'SELECT id FROM members WHERE mosaic_code IN (%%QUOTED_VALUE%%)',
        values: (1..66).map(&:to_s),
        input: 'checkbox',
        multiple: true
      }

      # mosaic attribute filter
      # lookup individual mosaic mosaic attributes
      Mosaic::MosaicAttribute.all.order('name ASC').each do |attribute|
        filters << {
          optgroup: 'Demographics',
          id: attribute.slug,
          label: "#{attribute.name} (DEPRECATED)",
          operators: %w[greater less],
          type: 'double',
          lambda: lambda do |rule|
            value = rule['value']
            operator = rule['operator'] == 'less' ? '<' : '>'
            "SELECT members.id FROM members JOIN mosaic_attribute_values mav ON mav.mosaic_code=members.mosaic_code WHERE mav.value #{operator} #{value} AND mav.mosaic_attribute_id=#{attribute.id}"
          end
        }
      end
    end

    org_settings = Rails.root.join("config/settings/searches/#{Settings.app.org_name}.rb")
    if File.exist? org_settings
      require org_settings
      filters |= org_filters
    end

    # Load dynamic values
    filters.each do |filter|
      values = filter[:values]
      if values.is_a? Proc
        filter[:values] = values.call
      end
    end

    filters.reject! { |filter|
      optgroup = filter[:optgroup]
      (optgroup == 'Actions' && !Settings.features.actions) ||
        (optgroup == 'Donations' && !Settings.features.donations) ||
        (optgroup == 'IRL' && !Settings.features.irl) ||
        (optgroup == 'Mailings' && !Settings.features.mailings) || (['Circles of Engagement', 'Drop Offs'].include?(optgroup) && !Settings.features.circles_of_engagement)
    }

    if Settings.searches.filters.present?
      filters.select { |filter| Settings.searches.filters.include? filter[:id] }
    else
      filters
    end
  end

  def to_hash_for_api
    as_json.slice("id", "name", "rules", "total_members", "complete", "permanent", "sql", "updated_at")
  end

  def self.parse(payload)
    search_params = payload.slice("name", "pinned", "permanent", "description")
    search_params['rules'] = clean_search_values(payload['search']) if payload['search'].present?
    search_params
  end

  def self.clean_search_values(payload)
    return nil unless payload

    if payload['input'].present? && payload['input'] == "text"
      if payload['value'].is_a?(String)
        payload['value'] = Cleanser.replace_smart_quotes(payload['value'].strip)
      elsif payload['value'].is_a?(Array)
        payload['value'].map! { |v| Cleanser.replace_smart_quotes(v.strip) }
      end
    else
      payload.each do |_k, v|
        if v.is_a?(Hash)
          clean_search_values v
        elsif v.is_a?(Array)
          v.flatten.each { |x| clean_search_values(x) if x.is_a?(Hash) }
        end
      end
    end
    payload
  end
end
