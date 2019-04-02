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
      list = FactoryBot.create(:list)
      FactoryBot.create(:list_member, list: list, member: @member)
      FactoryBot.create(:member_with_mobile)
      FactoryBot.create(:member)
      @batch_members = Member.all.with_mobile.in_batches.first
    end

    it 'returns valid object' do
      rows = ActiveModel::Serializer::CollectionSerializer.new(
        @batch_members,
        serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
        campaign_id: @spoke_campaign.id
      ).as_json
      expect(rows.count).to eq(2)
      expect(rows[0][:external_id]).to eq(ListMember.first.member_id)
      expect(rows[0][:cell]).to eq("+#{@member.mobile}")
      expect(rows[0][:campaign_id]).to eq(@spoke_campaign.id)
      expect(rows[0][:custom_fields]).to eq("{\"secret\":\"me_likes\"}")
    end

    it "only returns the most recently updated phone number" do
      @member.update_phone_number('61427700500', 'mobile')
      @member.update_phone_number('61427700600', 'mobile')
      @member.update_phone_number('61427700500', 'mobile')
      @batch_members = Member.all.with_phone_numbers.in_batches.first
      rows = ActiveModel::Serializer::CollectionSerializer.new(
        @batch_members,
        serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
        campaign_id: @spoke_campaign.id
      ).as_json
      expect(rows.first[:cell]).to eq('+61427700500')
    end

    context 'with a member with a postcode' do
      let!(:member_with_address) { double('member',
        mobile: '040000000',
        id: 1,
        last_name: nil,
        first_name: nil,
        flattened_custom_fields: {},
      )}

      it 'should return the postcode as location in the custom fields' do
        expect(member_with_address).to receive_message_chain(:address, :postcode).and_return('2291')
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          [member_with_address],
          serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
          campaign_id: @spoke_campaign.id
        ).as_json
        expect(rows[0][:custom_fields]).to eq("{\"location\":\"2291\"}")
      end
    end

    context 'with a member with with no postcode but a town' do
      let!(:member_with_address) { double('member',
        mobile: '040000000',
        id: 1,
        last_name: nil,
        first_name: nil,
        flattened_custom_fields: {},
      )}

      it 'should return the postcode as location in the custom fields' do
        expect(member_with_address).to receive_message_chain(:address, :postcode).and_return(nil)
        expect(member_with_address).to receive_message_chain(:address, :town).and_return('test town')
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          [member_with_address],
          serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
          campaign_id: @spoke_campaign.id
        ).as_json
        expect(rows[0][:custom_fields]).to eq("{\"location\":\"test town\"}")
      end
    end

    context 'with include_nearest_events passed' do
      let!(:member_with_address) { double('member',
        mobile: '040000000',
        id: 1,
        last_name: nil,
        first_name: nil,
        flattened_custom_fields: {},
      )}
      let!(:test_event) { {
        'name': 'test event',
        'local_start_time': DateTime.current,
        'local_end_time': DateTime.current + 2.hours,
        'location': 'test location'
      } }

      it 'should find all events near the user' do
        expect(member_with_address).to receive_message_chain(:upcoming_events).with(radius: 6, max_rsvps: 5).and_return([])
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          [member_with_address],
          serializer: IdentitySpoke::SpokeMemberSyncPushSerializer,
          campaign_id: @spoke_campaign.id,
          include_nearest_events: true,
          include_nearest_events_radius: 6,
          include_nearest_events_rsvp_max: 5,
        ).as_json
        upcoming_events = JSON.parse(rows[0][:custom_fields])
        expect(upcoming_events['events']).to eq([test_event])
        expect(upcoming_events['event_list']).to eq('1) Test event at test location (')
      end
    end
  end
end
