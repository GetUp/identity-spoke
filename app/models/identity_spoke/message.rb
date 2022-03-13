module IdentitySpoke
  class Message < ReadOnly
    self.table_name = "message"
    belongs_to :user, optional: true
    belongs_to :assignment, optional: true
    belongs_to :campaign_contact, optional: true

    scope :updated_messages, -> (last_created_at) {
      where('message.send_status != ?', 'ERROR')
      .where('message.created_at > ?', last_created_at)
      .order('message.created_at')
      .limit(Settings.spoke.pull_batch_amount)
    }

    scope :updated_messages_all, -> (last_created_at) {
      where('message.send_status != ?', 'ERROR')
      .where('message.created_at > ?', last_created_at)
    }
  end
end
