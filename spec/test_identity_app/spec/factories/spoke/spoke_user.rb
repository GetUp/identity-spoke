module IdentitySpoke
  FactoryBot.define do
    factory :spoke_user, class: User do
      auth0_id { Faker::Number.number(10) }
      first_name { 'Super' }
      last_name { 'Vollie' }
      cell { "+61411222333" }
      assigned_cell { "+614#{::Kernel.rand(10_000_000..99_999_999)}" }
      email { Faker::Internet.email }
      is_superadmin { true }
      terms { true }

      factory :empty_spoke_user do
        cell { 'xxx' }
        email { 'xxx' }
        assigned_cell { 'xxx' }
      end
    end
  end
end
