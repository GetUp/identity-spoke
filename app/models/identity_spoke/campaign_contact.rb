module IdentitySpoke
  class CampaignContact < ApplicationRecord
    include ReadOnly
    include ConnectionExtension
    self.table_name = "campaign_contact"
    belongs_to :campaign

    def self.add_members(batch)
      write_result = bulk_create(batch)
      write_result_length = write_result ? write_result.cmd_tuples : 0
      if write_result_length != batch.count
        Notify.warning("Spoke Insert: Some Rows Duplicate and Ignored", "Only #{write_result_length} out of #{batch.count} members were inserted. #{batch.inspect}")
      end
      write_result_length
    end
  end
end
