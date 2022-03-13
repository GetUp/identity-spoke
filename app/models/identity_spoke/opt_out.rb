module IdentitySpoke
  class OptOut < ReadOnly
    self.table_name = "opt_out"
    belongs_to :assignment
    belongs_to :organization

    scope :updated_opt_outs, -> (last_created_at) {
      where('opt_out.created_at > ?', last_created_at)
      .order('opt_out.created_at')
      .limit(Settings.spoke.pull_batch_amount)
    }

    scope :updated_opt_outs_all, -> (last_created_at) {
      where('opt_out.created_at > ?', last_created_at)
    }
  end
end
