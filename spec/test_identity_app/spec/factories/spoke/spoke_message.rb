module IdentitySpoke
  FactoryBot.define do
    factory :spoke_message, class: Message do
      is_from_contact { true }
      text { Faker::GreekPhilosophers.quote }
      service_response { Faker::Book.title }
      service { Faker::Book.title }
      service_id { Faker::Number.number(10) }
      send_status { '' }

      factory :spoke_message_delivered do
        send_status { 'DELIVERED' }
      end
    end
  end
end
