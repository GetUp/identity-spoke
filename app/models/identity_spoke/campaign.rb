module IdentitySpoke
  class Campaign < ReadOnly
    self.table_name = "campaign"
    belongs_to :organization
    has_many :campaign_contacts
    has_many :assignments
    has_many :interaction_steps

    scope :active, -> {
      where('is_started')
        .where('not is_archived')
        .order('created_at')
    }
  end
end
