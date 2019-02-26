module IdentitySpoke
  class CampaignContact < ApplicationRecord
    include ReadWrite
    include ConnectionExtension
    self.table_name = "campaign_contact"
    belongs_to :campaign
    belongs_to :assignment, optional: true
    has_many :question_responses

    def self.add_members(batch)
      OptOut.transaction do
        OptOut.connection.execute('lock table opt_out in share mode')
        write_result = bulk_create(remove_opt_outs(batch))
        write_result_length = write_result ? write_result.cmd_tuples : 0
        if write_result_length != batch.count
          Notify.warning("Spoke Insert: Some Rows Duplicate and Ignored", "Only #{write_result_length} out of #{batch.count} members were inserted. #{batch.inspect}")
        end
        write_result_length
      end
    end

    private

    def self.remove_opt_outs(batch)
      cells = batch.map{|row| row[:cell] }
      opted_out_cells = OptOut.where('cell in (?)', cells ).map{|opt_out| opt_out[:cell] }
      batch.reject{|row| opted_out_cells.include?(row[:cell]) }
    end
  end
end
