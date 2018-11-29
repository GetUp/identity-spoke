module IdentitySpoke
  class QuestionResponse < ApplicationRecord
    self.table_name = "question_response"
    include ReadOnly
    belongs_to :campaign_contact
    belongs_to :interaction_step
  end
end
