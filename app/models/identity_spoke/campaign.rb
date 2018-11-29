module IdentitySpoke
  class Campaign < ApplicationRecord
    self.table_name = "campaign"
    include ReadOnly
    belongs_to :organization
    has_many :campaign_contacts
    has_many :assignments
  end
end
