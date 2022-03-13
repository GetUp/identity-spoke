module IdentitySpoke
  class InteractionStep < ReadOnly
    self.table_name = "interaction_step"
    belongs_to :campaign
    has_many :question_responses
  end
end
