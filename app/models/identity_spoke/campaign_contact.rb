module IdentitySpoke
  class CampaignContact < ReadWrite
    include ConnectionExtension
    self.table_name = "campaign_contact"
    belongs_to :campaign
    belongs_to :assignment, optional: true
    has_many :question_responses, dependent: nil

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

      cells = batch.pluck(:cell)

      # Remove any already-opted-out phone numbers
      opted_out_cells = OptOut.where(cell: cells).pluck(:cell)
      batch = batch.reject { |row| opted_out_cells.include?(row[:cell]) }

      # Remove any phone numbers already in the campaign
      existing_cells = where(cell: cells)
                       .where(campaign_id: campaign_id)
                       .pluck(:cell)
      batch.reject { |row| existing_cells.include?(row[:cell]) }
    end

    def upsert_member
      # Upsert this contacted member in Identity.
      #
      # Use the campaign contact's external_id if known so that the
      # correct member gets used, irrespective of the phone number.
      # If no external is set that's fine - a new member will always
      # be created for the contact instead. But if so update the
      # contact with the new member's external id for it for future
      # upserts.
      #
      # See also User.upsert_member.
      #
      # Notes about the arguments here:
      #
      # 1. Don't include this campaign contact as an Identity external
      # id since they are per-Spoke-campaign and will be different for
      # each campaign.
      #
      # 2. Don't subscribe campaign contacts. They should be
      # subscribed already if they were pushed from Id, if not
      # (e.g. from a manual CSV upload) then they should be subscribed
      # manually in Id if appropriate.
      #
      # 3. Don't match based on phone numbers. As of 2024, our member
      # phone number data is in super bad shape, with the same number
      # appearing on multiple members. As a result, matching on phone
      # number only is as likely to be wrong as it is right.
      #
      # 4. Don't change anyone's names, the names here will likely be
      # sourced from Id anyway, and if not, should be treated as less
      # reliable than that in Id anyway
      member = UpsertMember.call(
        {
          phones: [
            { phone: cell.sub(/^[+]*/, '') }
          ],
          firstname: first_name,
          lastname: last_name,
          member_id: external_id.present? ? external_id.to_i : nil,
          ignore_phone_number_match: true,
        },
        entry_point: "#{SYSTEM_NAME}",
        new_member_opt_in: false,
        ignore_name_change: true,
      )

      if external_id.blank?
        update!(external_id: member.id.to_s)
      end

      return member
    end
  end
end
