describe IdentitySpoke::CampaignContact do
  context '#add_members' do
    before(:each) do
      clean_external_database

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
      IdentitySpoke::CampaignContact.add_members(@rows)
      expect(@spoke_campaign.campaign_contacts.count).to eq(2)
      expect(@spoke_campaign.campaign_contacts.find_by_cell("+#{@member.mobile}").first_name).to eq(@member.first_name) # Spoke allows external IDs to be text
    end

    it "doesn't insert duplicates into Spoke" do
      2.times do |index|
        IdentitySpoke::CampaignContact.add_members(@rows)
      end
      expect(@spoke_campaign.campaign_contacts.count).to eq(2)
      expect(@spoke_campaign.campaign_contacts.select('distinct cell').count).to eq(2)
    end
  end
end
