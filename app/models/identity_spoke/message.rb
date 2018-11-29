module IdentitySpoke
  class Message < ApplicationRecord
    include ReadOnly
    self.table_name = "message"
    belongs_to :assignment
    has_many :survey_results

    BATCH_AMOUNT=200

    def user
      assignment.user
    end

    def campaign_contact
      assignment.campaign_contact
    end

    scope :updated_messages, -> (last_created_at) {
      where('message.send_status = ?', 'DELIVERED')
      .where('message.created_at >= ?', last_created_at)
      .order('message.created_at')
      .limit(BATCH_AMOUNT)
    }
  end
end
