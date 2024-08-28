module IdentitySpoke
  class User < ReadWrite
    self.table_name = "user"
    has_many :assignment, dependent: nil
    has_many :message, dependent: nil

    def upsert_member
      # Upsert this Spoke backend account in Identity.
      #
      # Hook up both the Spoke account's id to Identity external id,
      # and vice-versa. We can do this here since unlike a
      # CampaignContact, User entities are long lived.
      #
      # See also CampaignContact.upsert_member.
      #
      # Notes about the arguments here:
      #
      # 1. Don't subscribe accounts. They should be staff or vollies
      # and hence subscribed already. If not, something has gone
      # wrong, but also they probably haven't been asked for consent.
      #
      # 2. Don't match based on phone numbers. As of 2024, our member
      # phone number data is in super bad shape, with the same number
      # appearing on multiple members. As a result, matching on phone
      # number only is as likely to be wrong as it is right.
      #
      # 3. Don't change anyone's names, the names here will likely be
      # sourced from Id anyway, and if not, should be treated as less
      # reliable than that in Id anyway.
      if self.extra.nil?
        self.extra = {}
      end

      member = UpsertMember.call(
        {
          emails: [
            { email: email }
          ],
          phones: [
            { phone: cell.sub(/^[+]*/, '') }
          ],
          firstname: first_name,
          lastname: last_name,
          member_id: self.extra.dig(:identity, :member_id),
          external_ids: {
            spoke: id.to_s
          },
          ignore_phone_number_match: true
        },
        entry_point: "#{SYSTEM_NAME}",
        new_member_opt_in: false,
        ignore_name_change: true
      )

      self.extra[:identity] = { member_id: member.id }
      save!

      return member
    end
  end
end
