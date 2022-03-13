module IdentitySpoke
  class Assignment < ReadOnly
    self.table_name = "assignment"
    has_one :opt_out
    has_many :campaign_contacts
    belongs_to :user
    belongs_to :campaign
  end
end
