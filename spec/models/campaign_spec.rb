describe IdentitySpoke::Campaign do
  context '#active' do
    before(:each) do
      spoke_organization = FactoryBot.create(:spoke_organization)
      2.times do
        FactoryBot.create(:spoke_campaign, is_started: true, is_archived: false, organization: spoke_organization)
      end
      FactoryBot.create(:spoke_campaign, is_started: true, is_archived: true, organization: spoke_organization)
      FactoryBot.create(:spoke_campaign, is_started: false, is_archived: true, organization: spoke_organization)
    end

    it 'returns the active campaigns' do
      expect(IdentitySpoke::Campaign.active.count).to eq(2)
      IdentitySpoke::Campaign.active.each do |campaign|
        expect(campaign).to have_attributes(is_started: true, is_archived: false)
      end
    end
  end
end
