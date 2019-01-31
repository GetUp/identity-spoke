require "identity_spoke/engine"

module IdentitySpoke
  SYSTEM_NAME='spoke'
  BATCH_AMOUNT=1000
  SYNCING='campaign'
  CONTACT_TYPE='sms'
  PULL_JOBS=[:fetch_new_messages, :fetch_new_opt_outs]

  def self.push(sync_id, members, external_system_params)
    begin
      external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
      external_campaign_name = Campaign.find(external_campaign_id).title

      yield members.with_mobile, external_campaign_name
    rescue => e
      raise e
    end
  end

  def self.push_in_batches(sync_id, members, external_system_params)
    begin
      external_campaign_id = JSON.parse(external_system_params)['campaign_id'].to_i
      members.in_batches(of: BATCH_AMOUNT).each_with_index do |batch_members, batch_index|
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

  def self.description(external_system_params, contact_campaign_name)
    "#{SYSTEM_NAME.titleize} - #{SYNCING.titleize}: #{contact_campaign_name} ##{JSON.parse(external_system_params)['campaign_id']} (#{CONTACT_TYPE})"
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

  def self.fetch_new_messages(force: false)
    ## Do not run method if another worker is currently processing this method
    return if self.worker_currenly_running?(__method__.to_s)

    last_created_at = Time.parse($redis.with { |r| r.get 'spoke:messages:last_created_at' } || '2019-01-01 00:00:00')
    updated_messages = Message.updated_messages(force ? DateTime.new() : last_created_at)

    iteration_method = force ? :find_each : :each
    updated_messages.send(iteration_method) do |message|
      self.delay(retry: false, queue: 'low').handle_new_message(message.id)
    end

    unless updated_messages.empty?
      $redis.with { |r| r.set 'spoke:messages:last_created_at', updated_messages.last.created_at }
    end

    updated_messages.size
  end

  def self.handle_new_message(message_id)
    ## Get the message
    message = IdentitySpoke::Message.find(message_id)

    ## Find who is the campaign contact for the message
    unless campaign_contact = IdentitySpoke::CampaignContact.find_by(campaign_id: message.assignment.campaign.id, cell: message.contact_number)
      Notify.warning "Spoke: CampaignContact Find Failed", "campaign_id: #{message.assignment.campaign.id}, cell: #{message.contact_number}"
      return
    end

    ## Create Members for both the user and campaign contact
    campaign_contact_member = Member.upsert_member(phones: [{ phone: campaign_contact.cell.sub(/^[+]*/,'') }], firstname: campaign_contact.first_name, lastname: campaign_contact.last_name)
    user_member = Member.upsert_member(phones: [{ phone: message.user.cell.sub(/^[+]*/,'') }], firstname: message.user.first_name, lastname: message.user.last_name)

    ## Assign the contactor and contactee according to if the message was from the campaign contact
    contactor = message.is_from_contact ? campaign_contact_member: user_member
    contactee = message.is_from_contact ? user_member : campaign_contact_member

    ## Find or create the contact campaign
    contact_campaign = ContactCampaign.find_or_initialize_by(external_id: message.assignment.campaign.id, system: SYSTEM_NAME)
    contact_campaign.update_attributes!(name: message.assignment.campaign.title, contact_type: CONTACT_TYPE)

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
      contact_response_key = ContactResponseKey.find_or_create_by!(key: qr.interaction_step.question, contact_campaign: contact_campaign)

      ## Create a contact response against the contact if no existing contact response exists for the contactee
      matched_contact_responses = contactee.contact_responses.where(value: qr.value, contact_response_key: contact_response_key)
      if matched_contact_responses.empty?
        ContactResponse.find_or_create_by!(contact: contact, value: qr.value, contact_response_key: contact_response_key)
      end
    end
  end

  def self.fetch_new_opt_outs(force: false)
    ## Do not run method if another worker is currently processing this method
    return if self.worker_currenly_running?(__method__.to_s)

    if Settings.spoke.opt_out_subscription_id
      last_created_at = Time.parse($redis.with { |r| r.get 'spoke:opt_outs:last_created_at' } || '1970-01-01 00:00:00')
      updated_opt_outs = IdentitySpoke::OptOut.updated_opt_outs(force ? DateTime.new() : last_created_at)

      iteration_method = force ? :find_each : :each
      updated_opt_outs.send(iteration_method) do |opt_out|
        self.delay(retry: false, queue: 'low').handle_new_opt_out(opt_out.id)
      end

      unless updated_opt_outs.empty?
        $redis.with { |r| r.set 'spoke:opt_outs:last_created_at', updated_opt_outs.last.created_at }
      end

      updated_opt_outs.size
    end
  end

  def self.handle_new_opt_out(opt_out_id)
    opt_out = IdentitySpoke::OptOut.find(opt_out_id)
    campaign_contact = IdentitySpoke::CampaignContact.where(cell: opt_out.cell).last
    if campaign_contact
      contactee = Member.upsert_member(phones: [{ phone: campaign_contact.cell.sub(/^[+]*/,'') }], firstname: campaign_contact.first_name, lastname: campaign_contact.last_name)
      subscription = Subscription.find(Settings.spoke.opt_out_subscription_id)
      contactee.unsubscribe_from(subscription, 'spoke:opt_out') if contactee
    end
  end
end