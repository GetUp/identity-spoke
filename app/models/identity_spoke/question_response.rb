module IdentitySpoke
  class QuestionResponse < ReadOnly
    self.table_name = "question_response"
    belongs_to :campaign_contact
    belongs_to :interaction_step
  end
end
