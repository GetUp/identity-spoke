module IdentitySpoke
  class InteractionStep < ApplicationRecord
    self.table_name = "interaction_step"
    include ReadOnly
    belongs_to :campaign
    has_many :question_responses
  end
end
