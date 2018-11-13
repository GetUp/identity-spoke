require 'rails_helper'

describe IdentitySpoke do
  context '#push' do
    before(:each) do
      clean_external_database

      @sync_id = 1
      @spoke_organization = FactoryBot.create(:spoke_organization)
      @spoke_campaign = FactoryBot.create(:spoke_campaign, organization: @spoke_organization)
      @external_system_params = JSON.generate({'campaign_id' => @spoke_campaign.id})

      2.times { FactoryBot.create(:member_with_mobile) }
      FactoryBot.create(:member_with_landline)
      FactoryBot.create(:member)
      @members = Member.all
    end

    context 'with valid parameters' do
      it 'yeilds correct campaign_name' do
        IdentitySpoke.push(@sync_id, @members, @external_system_params) do |members_with_phone_numbers, campaign_name|
          expect(campaign_name).to eq(@spoke_campaign.title)
        end
      end
      it 'yeilds members_with_phone_numbers' do
        IdentitySpoke.push(@sync_id, @members, @external_system_params) do |members_with_phone_numbers, campaign_name|
          expect(members_with_phone_numbers.count).to eq(2)
        end
      end
    end
  end

  context '#push_in_batches' do
    before(:each) do
      clean_external_database

      @sync_id = 1
      @spoke_organization = IdentitySpoke::Organization.create!(name: 'Torie Buster')
      @spoke_campaign = IdentitySpoke::Campaign.create!(title: 'Test campaign', description: 'progress', organization: @spoke_organization)
      @external_system_params = JSON.generate({'campaign_id' => @spoke_campaign.id})

      2.times { FactoryBot.create(:member_with_mobile) }
      FactoryBot.create(:member_with_landline)
      FactoryBot.create(:member)
      @members = Member.all.with_mobile
    end

    context 'with valid parameters' do
      it 'yeilds correct batch_index' do
        IdentitySpoke.push_in_batches(1, @members, @external_system_params) do |batch_index, write_result_count|
          expect(batch_index).to eq(0)
        end
      end
      it 'yeilds write_result_count' do
        IdentitySpoke.push_in_batches(1, @members, @external_system_params) do |batch_index, write_result_count|
          expect(write_result_count).to eq(2)
        end
      end
    end
  end
end
