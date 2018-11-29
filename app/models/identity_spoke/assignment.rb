module IdentitySpoke
  class Assignment < ApplicationRecord
    self.table_name = "assignment"
    include ReadOnly
    has_one :opt_out
    has_one :campaign_contact
    belongs_to :user
    belongs_to :campaign
  end
end
