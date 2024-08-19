module IdentitySpoke
  class CampaignContact < ReadWrite
    include ConnectionExtension
    self.table_name = "campaign_contact"
    belongs_to :campaign
    belongs_to :assignment, optional: true
    has_many :question_responses

    def self.add_members(campaign_id, batch)
      OptOut.transaction do
        OptOut.connection.execute('lock table opt_out in share mode')
        remaining = remove_exclusions_from_batch(campaign_id, batch)

        write_result = bulk_create(remaining)
        write_result_length = write_result ? write_result.cmd_tuples : 0
        if write_result_length != batch.count
          Notify.warning("Spoke Insert: Some Rows Duplicate and Ignored", "Only #{write_result_length} out of #{batch.count} members were inserted. #{batch.inspect}")
        end
        write_result_length
      end
    end

    def self.remove_exclusions_from_batch(campaign_id, batch)
      # Remove any duplicates in the same batch
      batch = batch.uniq { |row| row[:cell] }

      cells = batch.map { |row| row[:cell] }

      # Remove any already-opted-out phone numbers
      opted_out_cells = OptOut.where('cell in (?)', cells).map { |opt_out| opt_out[:cell] }
      batch = batch.reject { |row| opted_out_cells.include?(row[:cell]) }

      # Remove any phone numbers already in the campaign
      existing_cells = where('cell in (?)', cells)
                       .where('campaign_id = ?', campaign_id)
                       .map { |contact| contact[:cell] }
      batch.reject { |row| existing_cells.include?(row[:cell]) }
    end
  end
end
