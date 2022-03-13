module IdentitySpoke
  FactoryBot.define do
    factory :spoke_message, class: Message do
      is_from_contact { false }
      text { Faker::GreekPhilosophers.quote }
      service { Faker::Book.title }
      service_id { Faker::Number.number(digits: 10) }
      send_status { 'NOT_ATTEMPTED' }

      factory :spoke_message_delivered do
        send_status { 'DELIVERED' }
      end
      factory :spoke_message_errored do
        send_status { 'ERROR' }
      end
      factory :spoke_response_delivered do
        is_from_contact { true }
      end
    end
  end
end
