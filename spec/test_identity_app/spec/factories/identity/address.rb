FactoryBot.define do
  factory :address do
    line1 { Faker::Address.street_address }
    town { Faker::Address.city }
    postcode { Faker::Address.postcode }
    state { Faker::Address.state_abbr }
    country { Faker::Address.country }
  end
end
