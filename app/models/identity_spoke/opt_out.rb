module IdentitySpoke
  class OptOut < ApplicationRecord
    self.table_name = "opt_out"
    include ReadOnly
    belongs_to :assignment
    belongs_to :organization
  end
end
