FactoryBot.define do
  factory :list do
    name { Faker::Book.title }
  end
end
