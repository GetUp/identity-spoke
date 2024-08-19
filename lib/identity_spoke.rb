require "identity_spoke/engine"

module IdentitySpoke
  SYSTEM_NAME = 'spoke'.freeze
  SYNCING = 'campaign'.freeze
  CONTACT_TYPE = 'sms'.freeze
  PULL_JOBS = [[:fetch_active_campaigns, 10.minutes]].freeze
  MEMBER_RECORD_DATA_TYPE = 'object'.freeze
  MUTEX_EXPIRY_DURATION = 10.minutes

  def self.push(_sync_id, member_ids, external_system_params)
    begin
      external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
      external_campaign_name = Campaign.find(external_campaign_id).title
      members = Member.where(id: member_ids).with_mobile
      yield members, external_campaign_name
    rescue => e
      raise e
    end
  end

  def self.push_in_batches(_sync_id, members, external_system_params)
    begin
      external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
      members.in_batches(of: Settings.spoke.push_batch_amount).each_with_index do |batch_members, batch_index|
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          batch_members,
          serializer: SpokeMemberSyncPushSerializer,
          campaign_id: external_campaign_id
        ).as_json
        write_result_count = CampaignContact.add_members(external_campaign_id, rows)

        yield batch_index, write_result_count
      end
    rescue => e
      raise e
    end
  end

  def self.description(sync_type, external_system_params, contact_campaign_name)
    external_system_params_hash = JSON.parse(external_system_params)
    if sync_type === 'push'
      "#{SYSTEM_NAME.titleize} - #{SYNCING.titleize}: #{contact_campaign_name} ##{external_system_params_hash['campaign_id']} (#{CONTACT_TYPE})"
    else
      "#{SYSTEM_NAME.titleize}: #{external_system_params_hash['pull_job']}"
    end
  end

  def self.base_campaign_url(campaign_id)
    Settings.spoke.base_campaign_url ? sprintf(Settings.spoke.base_campaign_url, campaign_id.to_s) : nil
  end

  def self.get_pull_jobs
    defined?(PULL_JOBS) && PULL_JOBS.is_a?(Array) ? PULL_JOBS : []
  end

  def self.pull(sync_id, external_system_params)
    begin
      pull_job = JSON.parse(external_system_params)['pull_job'].to_s
      self.send(pull_job, sync_id) do |records_for_import_count, records_for_import, records_for_import_scope, pull_deferred|
        yield records_for_import_count, records_for_import, records_for_import_scope, pull_deferred
      end
    rescue => e
      raise e
    end
  end

  def self.fetch_new_messages(sync_id, force: false)
    begin
      mutex_acquired = acquire_mutex_lock(__method__.to_s, sync_id)
      unless mutex_acquired
        yield 0, {}, {}, true
        return
      end
      need_another_batch = fetch_new_messages_impl(sync_id, force) do |records_for_import_count, records_for_import, records_for_import_scope, pull_deferred|
        yield records_for_import_count, records_for_import, records_for_import_scope, pull_deferred
      end
    ensure
      release_mutex_lock(__method__.to_s) if mutex_acquired
    end
    schedule_pull_batch(:fetch_new_messages) if need_another_batch
  end

  def self.fetch_new_messages_impl(sync_id, force)
    started_at = DateTime.now
    last_created_at = get_redis_date('spoke:messages:last_created_at', Time.parse('2019-01-01 00:00:00'))
    last_id = (Sidekiq.redis { |r| r.get 'spoke:messages:last_id' } || 0).to_i
    updated_messages = Message.updated_messages(force ? DateTime.new() : last_created_at, last_id)
    updated_messages_all = Message.updated_messages_all(force ? DateTime.new() : last_created_at, last_id)

    iteration_method = force ? :find_each : :each

    updated_messages.send(iteration_method) do |message|
      handle_new_message(sync_id, message)
    end

    unless updated_messages.empty?
      set_redis_date('spoke:messages:last_created_at', updated_messages.last.created_at)
      Sidekiq.redis { |r| r.set 'spoke:messages:last_id', updated_messages.last.id }
    end

    execution_time_seconds = ((DateTime.now - started_at) * 24 * 60 * 60).to_i
    yield(
      updated_messages.size,
      updated_messages.pluck(:id),
      {
        scope: 'spoke:messages:last_created_at',
        scope_limit: Settings.spoke.pull_batch_amount,
        from: last_created_at,
        to: updated_messages.empty? ? nil : updated_messages.last.created_at,
        started_at: started_at,
        completed_at: DateTime.now,
        execution_time_seconds: execution_time_seconds,
        remaining_behind: updated_messages_all.count
      },
      false
    )

    updated_messages.count < updated_messages_all.count
  end

  def self.fetch_new_opt_outs(sync_id, force: false)
    begin
      mutex_acquired = acquire_mutex_lock(__method__.to_s, sync_id)
      unless mutex_acquired
        yield 0, {}, {}, true
        return
      end
      need_another_batch = fetch_new_opt_outs_impl(sync_id, force) do |records_for_import_count, records_for_import, records_for_import_scope, pull_deferred|
        yield records_for_import_count, records_for_import, records_for_import_scope, pull_deferred
      end
    ensure
      release_mutex_lock(__method__.to_s) if mutex_acquired
    end
    schedule_pull_batch(:fetch_new_opt_outs) if need_another_batch
  end

  def self.fetch_new_opt_outs_impl(sync_id, force)
    unless Settings.spoke.subscription_id
      Rails.logger.warn "#{SYSTEM_NAME.titleize} #{sync_id}: No subscription id configured, cannot import opt outs"
      yield 0, {}, {}, false
      return false
    end
    started_at = DateTime.now
    last_created_at = get_redis_date('spoke:opt_outs:last_created_at')
    last_id = (Sidekiq.redis { |r| r.get 'spoke:opt_outs:last_id' } || 0).to_i
    updated_opt_outs = IdentitySpoke::OptOut.updated_opt_outs(force ? DateTime.new() : last_created_at, last_id)
    updated_opt_outs_all = IdentitySpoke::OptOut.updated_opt_outs_all(force ? DateTime.new() : last_created_at, last_id)

    iteration_method = force ? :find_each : :each

    updated_opt_outs.send(iteration_method) do |opt_out|
      Rails.logger.info "#{SYSTEM_NAME.titleize} #{sync_id}: Handling opt-out: #{opt_out.id}/#{opt_out.created_at.utc.to_fs(:inspect)}"

      campaign_contact = IdentitySpoke::CampaignContact.where(cell: opt_out.cell).last
      if campaign_contact
        contactee = UpsertMember.call(
          {
            phones: [{ phone: campaign_contact.cell.sub(/^[+]*/, '') }],
            firstname: campaign_contact.first_name,
            lastname: campaign_contact.last_name,
            member_id: campaign_contact.external_id
          },
          entry_point: "#{SYSTEM_NAME}",
          ignore_name_change: false
        )
        subscription = Subscription.find(Settings.spoke.subscription_id)
        contactee.unsubscribe_from(subscription, reason: 'spoke:opt_out', event_time: DateTime.now) if contactee
      end
    end

    unless updated_opt_outs.empty?
      set_redis_date('spoke:opt_outs:last_created_at', updated_opt_outs.last.created_at)
      Sidekiq.redis { |r| r.set 'spoke:opt_outs:last_id', updated_opt_outs.last.id }
    end

    execution_time_seconds = ((DateTime.now - started_at) * 24 * 60 * 60).to_i
    yield(
      updated_opt_outs.size,
      updated_opt_outs.pluck(:id),
      {
        scope: 'spoke:opt_outs:last_created_at',
        scope_limit: 0,
        from: last_created_at,
        to: updated_opt_outs.empty? ? nil : updated_opt_outs.last.created_at,
        started_at: started_at,
        completed_at: DateTime.now,
        execution_time_seconds: execution_time_seconds,
        remaining_behind: updated_opt_outs_all.count
      },
      false
    )

    updated_opt_outs.count < updated_opt_outs_all.count
  end

  def self.fetch_active_campaigns(sync_id, force: false)
    begin
      mutex_acquired = acquire_mutex_lock(__method__.to_s, sync_id)
      unless mutex_acquired
        yield 0, {}, {}, true
        return
      end
      need_another_batch = fetch_active_campaigns_impl(sync_id, force) do |records_for_import_count, records_for_import, records_for_import_scope, pull_deferred|
        yield records_for_import_count, records_for_import, records_for_import_scope, pull_deferred
      end
    ensure
      release_mutex_lock(__method__.to_s) if mutex_acquired
    end
    schedule_pull_batch(:fetch_active_campaigns) if need_another_batch
    schedule_pull_batch(:fetch_new_messages)
    schedule_pull_batch(:fetch_new_opt_outs)
  end

  def self.fetch_active_campaigns_impl(sync_id, force)
    active_campaigns = IdentitySpoke::Campaign.active

    iteration_method = force ? :find_each : :each

    active_campaigns.send(iteration_method) do |campaign|
      Rails.logger.info "#{SYSTEM_NAME.titleize} #{sync_id}: Updating campaign #{campaign.id}"
      handle_campaign(campaign, true)
    end

    yield(
      active_campaigns.size,
      active_campaigns.pluck(:id),
      {},
      false
    )

    false # We never need another batch because we always process every campaign
  end

  private

  def self.handle_campaign(spoke_campaign, update_campaign)
    contact_campaign = ContactCampaign.find_or_initialize_by(
      external_id: spoke_campaign.id,
      system: SYSTEM_NAME
    )

    if contact_campaign.new_record? || update_campaign
      contact_campaign.update!(
        name: spoke_campaign.title,
        created_at: spoke_campaign.created_at,
        contact_type: CONTACT_TYPE
      )

      spoke_campaign.interaction_steps.each do |interaction_step|
        contact_response_key = ContactResponseKey.find_or_initialize_by(
          key: interaction_step.question,
          contact_campaign: contact_campaign
        )
        contact_response_key.save! if contact_response_key.new_record?
      end
    end

    contact_campaign
  end

  def self.handle_new_message(sync_id, message)
    Rails.logger.info "#{SYSTEM_NAME.titleize} #{sync_id}: Handling message: #{message.id}/#{message.created_at.utc.to_fs(:inspect)}"

    ## Find who is the campaign contact for the message
    campaign_contact_id = message.campaign_contact_id
    campaign_contact = IdentitySpoke::CampaignContact.find(campaign_contact_id) if campaign_contact_id
    if !campaign_contact
      Rails.logger.warn "#{SYSTEM_NAME.titleize} #{sync_id}: No campaign contact for message #{message.id}"
      return
    end

    ## Create Member for campaign contact
    campaign_contact_member = UpsertMember.call(
      {
        phones: [{ phone: campaign_contact.cell.sub(/^[+]*/, '') }],
        firstname: campaign_contact.first_name,
        lastname: campaign_contact.last_name,
        member_id: campaign_contact.external_id
      },
      entry_point: "#{SYSTEM_NAME}",
      ignore_name_change: false
    )

    user = message.user
    if user
      user_member = UpsertMember.call(
        {
          phones: [{ phone: user.cell.sub(/^[+]*/, '') }],
          firstname: user.first_name,
          lastname: user.last_name
        },
        entry_point: "#{SYSTEM_NAME}",
        ignore_name_change: false
      )
    else
      user_member = UpsertMember.call(
        {
          phones: [{ phone: message.user_number.sub(/^[+]*/, '') }],
        },
        entry_point: "#{SYSTEM_NAME}",
        ignore_name_change: false
      )
    end

    ## Assign the contactor and contactee according to if the message was from the campaign contact
    contactor = message.is_from_contact ? campaign_contact_member : user_member
    contactee = message.is_from_contact ? user_member : campaign_contact_member

    ## Find or create the contact campaign
    contact_campaign = handle_campaign(campaign_contact.campaign, false)

    ## Find or create the contact
    contact = Contact.find_or_initialize_by(external_id: message.id, system: SYSTEM_NAME)
    contact.update!(
      contactee: contactee,
      contactor: contactor,
      contact_campaign: contact_campaign,
      contact_type: CONTACT_TYPE,
      created_at: message.created_at,
      happened_at: message.created_at,
      status: message.send_status,
      notes: message.is_from_contact ? 'inbound' : 'outbound'
    )
    contact.reload

    ## Loop over all of the campaign contacts question responses if message is not from contact
    return if message.is_from_contact

    campaign_contact.question_responses.each do |qr|
      ### Find or create the contact response key
      contact_response_key = ContactResponseKey.find_or_initialize_by(key: qr.interaction_step.question, contact_campaign: contact_campaign)
      contact_response_key.save! if contact_response_key.new_record?

      ## Create a contact response against the contact if no existing contact response exists for the contactee
      matched_contact_responses = contactee.contact_responses.where(value: qr.value, contact_response_key: contact_response_key)
      if matched_contact_responses.empty?
        contact_response = ContactResponse.find_or_initialize_by(contact: contact, value: qr.value, contact_response_key: contact_response_key)
        contact_response.save! if contact_response.new_record?
      end
    end
  end

  def self.acquire_mutex_lock(method_name, sync_id)
    mutex_name = "#{SYSTEM_NAME}:mutex:#{method_name}"
    new_mutex_expiry = DateTime.now + MUTEX_EXPIRY_DURATION
    mutex_acquired = set_redis_date(mutex_name, new_mutex_expiry, true)
    unless mutex_acquired
      mutex_expiry = get_redis_date(mutex_name)
      if mutex_expiry.past?
        unless worker_currently_running?(method_name, sync_id)
          delete_redis_date(mutex_name)
          mutex_acquired = set_redis_date(mutex_name, new_mutex_expiry, true)
        end
      end
    end
    mutex_acquired
  end

  def self.release_mutex_lock(method_name)
    mutex_name = "#{SYSTEM_NAME}:mutex:#{method_name}"
    delete_redis_date(mutex_name)
  end

  def self.get_redis_date(redis_identifier, default_value = Time.at(0))
    date_str = Sidekiq.redis { |r| r.get redis_identifier }
    date_str ? Time.parse(date_str) : default_value
  end

  def self.set_redis_date(redis_identifier, date_time_value, as_mutex = false)
    date_str = date_time_value.utc.to_fs(:inspect) # Ensures fractional seconds are retained
    if as_mutex
      Sidekiq.redis { |r| r.set(redis_identifier, date_str, :nx => true) }
    else
      Sidekiq.redis { |r| r.set(redis_identifier, date_str) }
    end
  end

  def self.delete_redis_date(redis_identifier)
    Sidekiq.redis { |r| r.del redis_identifier }
  end

  def self.schedule_pull_batch(pull_job)
    sync = Sync.create!(
      external_system: SYSTEM_NAME,
      external_system_params: { pull_job: pull_job, time_to_run: DateTime.now }.to_json,
      sync_type: Sync::PULL_SYNC_TYPE
    )
    PullExternalSystemsWorker.perform_async(sync.id)
  end

  def self.worker_currently_running?(method_name, sync_id)
    workers = Sidekiq::Workers.new
    workers.each do |_process_id, _thread_id, work|
      args = work["payload"]["args"]
      worker_sync_id = (args.count > 0) ? args[0] : nil
      worker_sync = worker_sync_id ? Sync.find_by(id: worker_sync_id) : nil
      next unless worker_sync

      worker_system = worker_sync.external_system
      worker_method_name = JSON.parse(worker_sync.external_system_params)["pull_job"]
      already_running = (worker_system == SYSTEM_NAME &&
        worker_method_name == method_name &&
        worker_sync_id != sync_id)
      return true if already_running
    end
    return false
  end
end
