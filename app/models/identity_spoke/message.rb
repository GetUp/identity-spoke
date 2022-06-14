module IdentitySpoke
  class Message < ReadOnly
    self.table_name = "message"
    belongs_to :user, optional: true
    belongs_to :assignment, optional: true
    belongs_to :campaign_contact, optional: true

    scope :updated_messages, -> (last_created_at, last_id) {
      where('send_status != ?', 'ERROR')
      .where('created_at > ? or (created_at = ? and id > ?)', last_created_at, last_created_at, last_id)
      .order('created_at, id')
      .limit(Settings.spoke.pull_batch_amount)
    }

    scope :updated_messages_all, -> (last_created_at, last_id) {
      where('send_status != ?', 'ERROR')
      .where('created_at > ? or (created_at = ? and id > ?)', last_created_at, last_created_at, last_id)
    }
  end
end
