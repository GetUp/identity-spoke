module IdentitySpoke
  FactoryBot.define do
    factory :spoke_user, class: User do
      auth0_id { Faker::Number.number(10) }
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
      cell { "+614#{::Kernel.rand(10_000_000..99_999_999)}" }
      assigned_cell { "+614#{::Kernel.rand(10_000_000..99_999_999)}" }
      email { Faker::Internet.email }
      is_superadmin { true }
      terms { true }
    end
  end
end
