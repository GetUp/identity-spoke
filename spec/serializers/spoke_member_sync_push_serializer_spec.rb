describe IdentitySpoke::SpokeMemberSyncPushSerializer do
  context 'serialize' do
    before(:each) do
      clean_external_database
      Settings.stub_chain(:spoke) { {} }
      @sync_id = 1
      @spoke_organization = FactoryBot.create(:spoke_organization)
      @spoke_campaign = FactoryBot.create(:spoke_campaign, organization: @spoke_organization)
      @external_system_params = JSON.generate({'campaign_id' => @spoke_campaign.id})
      @member = FactoryBot.create(:member_with_mobile_and_custom_fields)
      FactoryBot.create(:member_with_mobile)
      FactoryBot.create(:member)
      @batch_members = Member.all.with_mobile.in_batches.first
    end

    it 'returns valid object' do
      rows = ActiveModel::Serializer::CollectionSerializer.new(
        [@member],
        serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
        campaign_id: @spoke_campaign.id
      ).as_json
      expect(rows[0][:external_id]).to eq(@member.id)
      expect(rows[0][:cell]).to eq("+#{@member.phone_numbers.mobile.first.phone}")
      expect(rows[0][:campaign_id]).to eq(@spoke_campaign.id)
      expect(rows[0][:custom_fields]).to eq("{\"secret\":\"me_likes\"}")
    end

    it "only returns the most recently updated phone number" do
      @member.update_phone_number('61427700500', 'mobile')
      @member.update_phone_number('61427700600', 'mobile')
      @member.update_phone_number('61427700500', 'mobile')
      @batch_members = [@member]
      rows = ActiveModel::Serializer::CollectionSerializer.new(
        @batch_members,
        serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
        campaign_id: @spoke_campaign.id
      ).as_json
      expect(rows.first[:cell]).to eq('+61427700500')
    end

    context 'with a member with a postcode' do
      @member = FactoryBot.create(:member_with_mobile)

      it 'should return the postcode as location in the custom fields' do
        address = FactoryBot.create(:address, member: @member)
        allow(@member).to receive(:address).and_return(address)
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          [@member],
          serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
          campaign_id: @spoke_campaign.id
        ).as_json
        custom_fields = JSON.parse(rows[0][:custom_fields])
        expect(custom_fields['secret']).to eq('me_likes')
        expect(custom_fields['postcode']).to eq(address.postcode)
      end
    end

    context 'with a member with with no postcode but a town' do
      @member = FactoryBot.create(:member_with_mobile)

      it 'should return the postcode as location in the custom fields' do
        address = FactoryBot.create(:address, member: @member)
        allow(@member).to receive(:address).and_return(address)
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          [@member],
          serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
          campaign_id: @spoke_campaign.id
        ).as_json
        custom_fields = JSON.parse(rows[0][:custom_fields])
        expect(custom_fields['secret']).to eq('me_likes')
        expect(custom_fields['address']['suburb']).to eq(address.town)
      end
    end
  end
end
