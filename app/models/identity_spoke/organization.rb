module IdentitySpoke
  class Organization < ReadOnly
    self.table_name = "organization"
    has_many :campaigns
    has_many :opt_outs
  end
end
