module IdentitySpoke
  FactoryBot.define do
    factory :spoke_campaign, class: Campaign do
      title { Faker::Book.title }
      description { 'progress' }
    end
  end
end
