module IdentitySpoke
  class OptOut < ApplicationRecord
    self.table_name = "opt_out"
    include ReadOnly
    belongs_to :assignment
    belongs_to :organization

    BATCH_AMOUNT=100

    scope :updated_opt_outs, -> (last_created_at) {
      where('opt_out.created_at >= ?', last_created_at)
      .order('opt_out.created_at')
      .limit(BATCH_AMOUNT)
    }
  end
end
