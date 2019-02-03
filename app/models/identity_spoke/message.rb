module IdentitySpoke
  class Message < ApplicationRecord
    include ReadOnly
    self.table_name = "message"
    belongs_to :assignment
    has_many :survey_results

    def user
      assignment.user
    end

    scope :updated_messages, -> (last_created_at) {
      where('message.send_status != ?', 'ERROR')
      .where('message.created_at >= ?', last_created_at)
      .order('message.created_at')
      .limit(IdentitySpoke.get_pull_batch_amount)
    }
  end
end
