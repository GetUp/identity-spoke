require "identity_spoke/engine"

module IdentitySpoke
  SYSTEM_NAME='spoke'
  BATCH_AMOUNT=1000
  SYNCING='campaign'
  CONTACT_TYPE='sms'

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
end
