module IdentitySpoke
  class Organization < ApplicationRecord
    self.table_name = "organization"
    include ReadOnly
    has_many :campaigns
    has_many :opt_outs
  end
end
