module IdentitySpoke
  class Assignment < ReadOnly
    self.table_name = "assignment"
    has_one :opt_out, dependent: nil
    has_many :campaign_contact, dependent: nil
    belongs_to :user
    belongs_to :campaign
  end
end
