FactoryBot.define do
  factory :member do
    name { Faker::Name.name_with_middle }
    email { Faker::Internet.email }

    factory :member_with_mobile do
      after(:create) do |member, _evaluator|
        create(:mobile_number, member: member)
      end

      factory :member_with_mobile_and_custom_fields do
        after(:create) do |member, _evaluator|
          create(:custom_field, member: member, custom_field_key: FactoryBot.create(:custom_field_key))
        end
      end
    end

    factory :member_with_landline do
      after(:create) do |member, _evaluator|
        create(:landline_number, member: member)
      end
    end
  end
end
