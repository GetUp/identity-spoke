module IdentitySpoke
  class Organization < ReadOnly
    self.table_name = "organization"
    has_many :campaigns, dependent: nil
    has_many :opt_outs, dependent: nil
  end
end
