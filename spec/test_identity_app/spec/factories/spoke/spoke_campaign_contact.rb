module IdentitySpoke
  FactoryBot.define do
    factory :spoke_campaign_contact, class: CampaignContact do
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
    end
  end
end
