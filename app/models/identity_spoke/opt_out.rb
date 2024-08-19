module IdentitySpoke
  class OptOut < ReadOnly
    self.table_name = "opt_out"
    belongs_to :assignment
    belongs_to :organization

    scope :updated_opt_outs, ->(last_created_at, last_id) {
      where('created_at > ? or (created_at = ? and id > ?)', last_created_at, last_created_at, last_id)
        .order('created_at, id')
        .limit(Settings.spoke.pull_batch_amount)
    }

    scope :updated_opt_outs_all, ->(last_created_at, last_id) {
      where('created_at > ? or (created_at = ? and id > ?)', last_created_at, last_created_at, last_id)
    }
  end
end
