describe IdentitySpoke::CampaignContact do
  context '#add_members' do
    before(:each) do
      @spoke_organization = FactoryBot.create(:spoke_organization)
      @spoke_campaign = FactoryBot.create(:spoke_campaign, organization: @spoke_organization)
      @member = FactoryBot.create(:member_with_mobile)
      FactoryBot.create(:member_with_mobile)
      @batch_members = Member.all
      @rows = ActiveModel::Serializer::CollectionSerializer.new(
        @batch_members,
        serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
        campaign_id: @spoke_campaign.id
      ).as_json
    end

    it 'has inserted the correct campaign contacts to Spoke' do
      IdentitySpoke::CampaignContact.add_members(@spoke_campaign.id, @rows)
      expect(@spoke_campaign.campaign_contacts.count).to eq(2)
      expect(@spoke_campaign.campaign_contacts.find_by(cell: "+#{@member.phone_numbers.mobile.first.phone}").first_name).to eq(@member.first_name) # Spoke allows external IDs to be text
    end

    it "doesn't insert duplicates already existing into Spoke" do
      2.times do |_index|
        IdentitySpoke::CampaignContact.add_members(@spoke_campaign.id, @rows)
      end
      expect(@spoke_campaign.campaign_contacts.count).to eq(2)
      expect(@spoke_campaign.campaign_contacts.select('distinct cell').count).to eq(2)
    end

    it "doesn't insert duplicates from the same batch into Spoke" do
      double_up = ActiveModel::Serializer::CollectionSerializer.new(
        [@member, @member],
        serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
        campaign_id: @spoke_campaign.id
      ).as_json

      IdentitySpoke::CampaignContact.add_members(@spoke_campaign.id, double_up)
      expect(@spoke_campaign.campaign_contacts.count).to eq(1)
      expect(@spoke_campaign.campaign_contacts.select('distinct cell').count).to eq(1)
    end

    context 'with an opt out for a campaign contact' do
      let!(:member) { FactoryBot.create(:member_with_mobile) }
      let!(:organization) { FactoryBot.create(:spoke_organization) }
      let!(:user) { FactoryBot.create(:spoke_user) }
      let!(:campaign) { FactoryBot.create(:spoke_campaign, organization: organization) }
      let!(:assignment) { FactoryBot.create(:spoke_assignment, user: user, campaign: campaign) }
      let!(:opt_out) {
        FactoryBot.create(
          :spoke_opt_out,
          cell: "+#{member.phone_numbers.mobile.first.phone}",
          assignment: assignment,
          organization: organization
        )
      }

      it 'should not insert the campaign contact' do
        inserted_records = IdentitySpoke::CampaignContact.add_members(
          @spoke_campaign.id,
          ActiveModel::Serializer::CollectionSerializer.new(
            [member],
            serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
            campaign_id: campaign.id
          ).as_json
        )
        expect(inserted_records).to eq(0)
        expect(campaign.campaign_contacts.count).to eq(0)
      end
    end
  end
end
