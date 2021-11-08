require "identity_spoke/engine"

module IdentitySpoke
  SYSTEM_NAME = 'spoke'
  SYNCING = 'campaign'
  CONTACT_TYPE = 'sms'
  PULL_JOBS = [[:fetch_new_messages, 5.minutes], [:fetch_new_opt_outs, 30.minutes], [:fetch_active_campaigns, 10.minutes]]
  MEMBER_RECORD_DATA_TYPE='object'

  def self.push(sync_id, member_ids, external_system_params)
    begin
      external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
      external_campaign_name = Campaign.find(external_campaign_id).title
      members = Member.where(id: member_ids).with_mobile
      yield members, external_campaign_name
    rescue => e
      raise e
    end
  end

  def self.push_in_batches(sync_id, members, external_system_params)
    begin
      external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
      members.in_batches(of: Settings.spoke.push_batch_amount).each_with_index do |batch_members, batch_index|
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          batch_members,
          serializer: SpokeMemberSyncPushSerializer,
          campaign_id: external_campaign_id
        ).as_json
        write_result_count = CampaignContact.add_members(rows)

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

  def self.worker_currenly_running?(method_name)
    workers = Sidekiq::Workers.new
    workers.each do |_process_id, _thread_id, work|
      matched_process = work["payload"]["args"] = [SYSTEM_NAME, method_name]
      if matched_process
        puts ">>> #{SYSTEM_NAME.titleize} #{method_name} skipping as worker already running ..."
        return true
      end
    end
    puts ">>> #{SYSTEM_NAME.titleize} #{method_name} running ..."
    return false
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
    ## Do not run method if another worker is currently processing this method
    yield 0, {}, {}, true if self.worker_currenly_running?(__method__.to_s)

    started_at = DateTime.now
    last_created_at = Time.parse($redis.with { |r| r.get 'spoke:messages:last_created_at' } || '2019-01-01 00:00:00')
    updated_messages = Message.updated_messages(force ? DateTime.new() : last_created_at)
    updated_messages_all = Message.updated_messages_all(force ? DateTime.new() : last_created_at)

    iteration_method = force ? :find_each : :each
    updated_messages.send(iteration_method) do |message|
      self.delay(retry: false, queue: 'low').handle_new_message(sync_id, message.id)
    end

    unless updated_messages.empty?
      $redis.with { |r| r.set 'spoke:messages:last_created_at', updated_messages.last.created_at }
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
  end

  def self.handle_new_message(sync_id, message_id)
    ## Get the message
    message = IdentitySpoke::Message.find(message_id)

    ## Find who is the campaign contact for the message
    unless campaign_contact = IdentitySpoke::CampaignContact.find(message.campaign_contact_id)
      Notify.warning "Spoke: CampaignContact Find Failed", "campaign_id: #{message.campaign_contact_id}, cell: #{message.contact_number}"
      return
    end

    ## Create Member for campaign contact
    campaign_contact_member = UpsertMember.call(
      {
        phones: [{ phone: campaign_contact.cell.sub(/^[+]*/,'') }],
        firstname: campaign_contact.first_name,
        lastname: campaign_contact.last_name,
        member_id: campaign_contact.external_id
      },
      entry_point: "#{SYSTEM_NAME}:#{__method__.to_s}",
      ignore_name_change: false
    )
    ## Create Member for user if message.user_id is not null
    if message.user_id.present?
      user = IdentitySpoke::User.find(message.user_id)
      user_member = UpsertMember.call(
        {
          phones: [{ phone: user.cell.sub(/^[+]*/,'') }],
          firstname: user.first_name,
          lastname: user.last_name
        },
        entry_point: "#{SYSTEM_NAME}:#{__method__.to_s}",
        ignore_name_change: false
      )
    end

    ## Assign the contactor and contactee according to if the message was from the campaign contact
    contactor = message.is_from_contact ? campaign_contact_member : user_member
    contactee = message.is_from_contact ? user_member : campaign_contact_member

    ## Find or create the contact campaign
    contact_campaign = ContactCampaign.find_or_initialize_by(external_id: campaign_contact.campaign_id, system: SYSTEM_NAME)
    contact_campaign.update_attributes!(name: campaign_contact.campaign.title, contact_type: CONTACT_TYPE)

    ## Find or create the contact
    contact = Contact.find_or_initialize_by(external_id: message.id, system: SYSTEM_NAME)
    contact.update_attributes!(contactee: contactee,
                              contactor: contactor,
                              contact_campaign: contact_campaign,
                              contact_type: CONTACT_TYPE,
                              happened_at: message.created_at,
                              status: message.send_status,
                              notes: message.is_from_contact ? 'inbound' : 'outbound')
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

  def self.fetch_new_opt_outs(sync_id, force: false)
    ## Do not run method if another worker is currently processing this method
    yield 0, {}, {}, true if self.worker_currenly_running?(__method__.to_s)

    if Settings.spoke.subscription_id
      started_at = DateTime.now
      last_created_at = Time.parse($redis.with { |r| r.get 'spoke:opt_outs:last_created_at' } || '1970-01-01 00:00:00')
      updated_opt_outs = IdentitySpoke::OptOut.updated_opt_outs(force ? DateTime.new() : last_created_at)
      updated_opt_outs_all = IdentitySpoke::OptOut.updated_opt_outs_all(force ? DateTime.new() : last_created_at)

      iteration_method = force ? :find_each : :each
      updated_opt_outs.send(iteration_method) do |opt_out|
        self.delay(retry: false, queue: 'low').handle_new_opt_out(sync_id, opt_out.id)
      end

      unless updated_opt_outs.empty?
        $redis.with { |r| r.set 'spoke:opt_outs:last_created_at', updated_opt_outs.last.created_at }
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
    end
  end

  def self.handle_new_opt_out(sync_id, opt_out_id)
    opt_out = IdentitySpoke::OptOut.find(opt_out_id)
    campaign_contact = IdentitySpoke::CampaignContact.where(cell: opt_out.cell).last
    if campaign_contact
      contactee = UpsertMember.call(
        {
          phones: [{ phone: campaign_contact.cell.sub(/^[+]*/,'') }],
          firstname: campaign_contact.first_name,
          lastname: campaign_contact.last_name,
          member_id: campaign_contact.external_id
        },
        entry_point: "#{SYSTEM_NAME}:#{__method__.to_s}",
        ignore_name_change: false
      )
      subscription = Subscription.find(Settings.spoke.subscription_id)
      contactee.unsubscribe_from(subscription, reason: 'spoke:opt_out', event_time: DateTime.now) if contactee
    end
  end

  def self.fetch_active_campaigns(sync_id, force: false)
    ## Do not run method if another worker is currently processing this method
    yield 0, {}, {}, true if self.worker_currenly_running?(__method__.to_s)

    active_campaigns = IdentitySpoke::Campaign.active

    iteration_method = force ? :find_each : :each

    active_campaigns.send(iteration_method) do |campaign|
      self.delay(retry: false, queue: 'low').handle_campaign(sync_id, campaign.id)
    end

    yield(
      active_campaigns.size,
      active_campaigns.pluck(:id),
      {},
      false
    )
  end

  def self.handle_campaign(sync_id, campaign_id)
    campaign = IdentitySpoke::Campaign.find(campaign_id)

    contact_campaign = ContactCampaign.find_or_initialize_by(external_id: campaign.id, system: SYSTEM_NAME)
    contact_campaign.update!(name: campaign.title, contact_type: CONTACT_TYPE)

    campaign.interaction_steps.each do |interaction_step|
      contact_response_key = ContactResponseKey.find_or_initialize_by(key: interaction_step.question, contact_campaign: contact_campaign)
      contact_response_key.save! if contact_response_key.new_record?
    end
  end
end
