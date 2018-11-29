module IdentitySpoke
  FactoryBot.define do
    factory :spoke_interaction_step, class: InteractionStep do
      question { Faker::Book.title }
      script { Faker::GreekPhilosophers.quote }
      answer_option { Faker::Book.title }
      answer_actions { Faker::Book.title }
    end
  end
end
