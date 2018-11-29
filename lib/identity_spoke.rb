require "identity_spoke/engine"

module IdentitySpoke
  SYSTEM_NAME='spoke'
  BATCH_AMOUNT=1000
  SYNCING='campaign'
  CONTACT_TYPE='sms'
  PULL_JOBS=[:fetch_new_messages]

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

  def self.fetch_new_messages(force: false)
    last_created_at = Time.parse($redis.with { |r| r.get 'spoke:messages:last_created_at' } || '1970-01-01 00:00:00')
    updated_messages = Message.updated_messages(force ? DateTime.new() : last_created_at)

    iteration_method = force ? :find_each : :each

    updated_messages.send(iteration_method) do |message|
      contact = Contact.find_or_initialize_by(external_id: message.id, system: SYSTEM_NAME)
      contactee = Member.upsert_member(phones: [{ phone: message.campaign_contact.cell.sub(/^[+]*/,'') }], firstname: message.campaign_contact.first_name, lastname: message.campaign_contact.last_name)

      unless contactee
        Notify.warning "Spoke: Contactee Insert Failed", "Contactee #{message.campaign_contact.inspect} could not be inserted because the contactee could not be created"
        next
      end

      # Texter conditional upsert phone
      if message.user
        contactor = Member.upsert_member(phones: [{ phone: message.user.cell.sub(/^[+]*/,'') }])
      else
        contactor = nil
      end

      contact_campaign = ContactCampaign.find_or_create_by(external_id: message.assignment.campaign.id, system: SYSTEM_NAME)
      contact_campaign.update_attributes(name: message.assignment.campaign.title, contact_type: CONTACT_TYPE)

      contact.update_attributes(contactee: contactee,
                                contactor: contactor,
                                contact_campaign: contact_campaign,
                                contact_type: CONTACT_TYPE,
                                happened_at: message.created_at,
                                status: message.send_status,
                                notes: message.is_from_contact ? 'inbound' : 'outbound')
      contact.reload

      ## Process Opt Outs
      if Settings.spoke.opt_out_subscription_id
        if message.assignment.opt_out
          subscription = Subscription.find(Settings.spoke.opt_out_subscription_id)
          contactee.unsubscribe_from(subscription, 'spoke:opt_out')
        end
      end

      message.campaign_contact.question_responses.each do |qr|
        contact_response_key = ContactResponseKey.find_or_create_by(key: qr.interaction_step.question, contact_campaign: contact_campaign)
        ContactResponse.find_or_create_by(contact: contact, value: qr.value, contact_response_key: contact_response_key)
      end
    end

    unless updated_messages.empty?
      $redis.with { |r| r.set 'spoke:messages:last_created_at', updated_messages.last.created_at }
    end

    updated_messages.size
  end
end
