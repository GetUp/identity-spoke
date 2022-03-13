require 'rails_helper'

describe IdentitySpoke do
  context '#pull' do
    before(:each) do
      clean_external_database
      @sync_id = 1
      @external_system_params = JSON.generate({'pull_job' => 'fetch_new_messages'})
    end

    context 'with valid parameters' do
      it 'should call the corresponding method'  do
        expect(IdentitySpoke).to receive(:fetch_new_messages).exactly(1).times.with(1)
        IdentitySpoke.pull(@sync_id, @external_system_params)
      end
    end
  end

  context 'fetching new messages' do

    before(:all) do
      Sidekiq::Testing.inline!
    end

    after(:all) do
      Sidekiq::Testing.fake!
    end

    before(:each) do
      clean_external_database
      $redis.reset

      @sync_id = 1
      @subscription = FactoryBot.create(:sms_subscription)
      Settings.stub_chain(:spoke, :push_batch_amount) { nil }
      Settings.stub_chain(:spoke, :pull_batch_amount) { nil }

      @time = Time.now - 120.seconds
      @spoke_organization = FactoryBot.create(:spoke_organization)
      @spoke_campaign = FactoryBot.create(:spoke_campaign, title: 'Test', organization: @spoke_organization)
      @spoke_user = FactoryBot.create(:spoke_user)
      @interaction_step1 = FactoryBot.create(:spoke_interaction_step, campaign: @spoke_campaign, question: 'voting_intention')
      @interaction_step2 = FactoryBot.create(:spoke_interaction_step, campaign: @spoke_campaign, question: 'favorite_party')
      3.times do |n|
        n += 1
        spoke_assignment = FactoryBot.create(
          :spoke_assignment,
          user: @spoke_user,
          campaign: @spoke_campaign
        )
        campaign_contact = FactoryBot.create(
          :spoke_campaign_contact,
          assignment: spoke_assignment,
          first_name: "Bob#{n}",
          cell: "+6142770040#{n}",
          campaign: @spoke_campaign
        )
        FactoryBot.create(
          :spoke_message_delivered,
          id: n,
          created_at: @time,
          assignment: spoke_assignment,
          campaign_contact_id: campaign_contact.id,
          user_id: @spoke_user.id,
          user_number: @spoke_user.cell,
          contact_number: campaign_contact.cell
        )
        FactoryBot.create(
          :spoke_message_errored,
          id: n+3,
          created_at: @time,
          assignment: spoke_assignment,
          campaign_contact_id: campaign_contact.id,
          user_id: @spoke_user.id,
          user_number: @spoke_user.cell,
          contact_number: campaign_contact.cell
        )
        FactoryBot.create(
          :spoke_response_delivered,
          id: n+6,
          created_at: @time,
          assignment: spoke_assignment,
          campaign_contact_id: campaign_contact.id,
          user_id: @spoke_user.id,
          user_number: @spoke_user.cell,
          contact_number: campaign_contact.cell
        )
        FactoryBot.create(
          :spoke_question_response,
          value: 'yes',
          interaction_step: @interaction_step1,
          campaign_contact: campaign_contact
        )
        FactoryBot.create(
          :spoke_question_response,
          value: 'no',
          interaction_step: @interaction_step2,
          campaign_contact: campaign_contact
        )
        FactoryBot.create(
          :spoke_question_response,
          value: 'maybe',
          interaction_step: @interaction_step2,
          campaign_contact: campaign_contact
        )
      end
    end

    it 'should create new members if none exist' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Member.count).to eq(4)
    end

    it 'should create new members for campaign contacts' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      member = Member.find_by_phone('61427700401')
      expect(member).to have_attributes(first_name: 'Bob1')
      expect(member.contacts_received.count).to eq(1)
      expect(member.contacts_made.count).to eq(1)
    end

    it 'should create new members for user if none exist' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      member = Member.find_by_phone('61411222333')
      expect(member).to have_attributes(first_name: 'Super', last_name: 'Vollie')
      expect(member.contacts_received.count).to eq(3)
      expect(member.contacts_made.count).to eq(3)
    end    

    it 'should match existing members for campaign contacts and user' do
      IdentitySpoke::CampaignContact.all.each do |campaign_contact|
        UpsertMember.call(
          {
            firstname: campaign_contact.first_name,
            lastname: campaign_contact.last_name,
            phones: [{ phone: campaign_contact.cell.sub(/^[+]*/,'') }]
          },
          entry_point: "#{IdentitySpoke::SYSTEM_NAME}:test",
        )
      end
      user = IdentitySpoke::User.last
      UpsertMember.call(
        {
          firstname: user.first_name,
          lastname: user.last_name,
          phones: [{ phone: user.cell.sub(/^[+]*/,'') }]
        },
        entry_point: "#{IdentitySpoke::SYSTEM_NAME}:test",
      )

      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Member.count).to eq(4)
    end

    it 'should create a contact campaign' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(ContactCampaign.count).to eq(1)
      expect(ContactCampaign.first.contacts.count).to eq(6)
      expect(ContactCampaign.first).to have_attributes(name: @spoke_campaign.title, external_id: @spoke_campaign.id, system: 'spoke', contact_type: 'sms')
    end

    it 'should fetch the new outbound contacts and insert them' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.where(notes: 'outbound').count).to eq(3)
    end

    it 'should fetch the new inbound contacts and insert them' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.where(notes: 'outbound').count).to eq(3)
    end

    context('with force=true passed as parameter') do
      ContactResponse.all.destroy_all
      Contact.all.destroy_all
      before { IdentitySpoke::Message.update_all(created_at: '1960-01-01 00:00:00') }

      it 'should ignore the last_created_at and fetch the new contacts and insert them' do
        IdentitySpoke.fetch_new_messages(@sync_id, force: true) {}
        expect(Contact.count).to eq(6)
      end
    end

    it 'should record contactee and contactor details on contact' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      contact = Contact.find_by_external_id('1')
      contactee = Member.find_by_phone(IdentitySpoke::Message.first.contact_number.sub(/^[+]*/,''))
      contactor = Member.find_by_phone(@spoke_user.cell.sub(/^[+]*/,''))

      expect(contact.contactee_id).to eq(contactee.id)
      expect(contact.contactor_id).to eq(contactor.id)
    end

    it 'should record specific details on contact' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.find_by_external_id('1')).to have_attributes(system: 'spoke', contact_type: 'sms', status: 'DELIVERED')
      expect(Contact.find_by_external_id('1').happened_at.utc.to_s).to eq(@time.utc.to_s)
    end

    it 'should create contact with a landline number set' do
      spoke_assignment = FactoryBot.create(
        :spoke_assignment,
        user: @spoke_user,
        campaign: @spoke_campaign
      )
      campaign_contact = FactoryBot.create(
        :spoke_campaign_contact,
        first_name: 'HomeBoy',
        cell: '+61727700400',
        campaign: @spoke_campaign,
        assignment: spoke_assignment
      )
      message = FactoryBot.create(
        :spoke_message_delivered,
        id: '123',
        created_at: @time,
        send_status: 'DELIVERED',
        assignment: spoke_assignment,
        campaign_contact_id: campaign_contact.id,
        contact_number: campaign_contact.cell,
        user_id: @spoke_user.id,
        user_number: @spoke_user.cell
      )
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.where(external_id: '123').first).to have_attributes(status: 'DELIVERED')
      expect(Contact.where(external_id: '123').first.happened_at.utc.to_s).to eq(@time.utc.to_s)
      expect(Contact.where(external_id: '123').first.contactee.phone).to eq('61727700400')
    end

    it 'should create contact if there is no name st' do
      spoke_assignment = FactoryBot.create(
        :spoke_assignment,
        user: @spoke_user,
        campaign: @spoke_campaign
      )
      campaign_contact = FactoryBot.create(
        :spoke_campaign_contact,
        cell: '+61427700409',
        campaign: @spoke_campaign,
        assignment: spoke_assignment
      )
      message = FactoryBot.create(
        :spoke_message_delivered,
        id: IdentitySpoke::Message.maximum(:id).to_i + 1,
        created_at: @time,
        send_status: 'DELIVERED',
        assignment: spoke_assignment,
        campaign_contact_id: campaign_contact.id,
        contact_number: campaign_contact.cell,
        user_id: @spoke_user.id,
        user_number: @spoke_user.cell,
      )
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.last.contactee.phone).to eq('61427700409')
    end

    it 'should upsert messages' do
      member = FactoryBot.create(:member, first_name: 'Janis')
      member.update_phone_number('61427700401')
      FactoryBot.create(:contact, contactee: member, external_id: '2')
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.count).to eq(6)
      expect(member.contacts_received.count).to eq(1)
    end

    it 'should be idempotent' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      contact_hash = Contact.all.select('contactee_id, contactor_id, duration, system, contact_campaign_id').as_json
      cr_count = ContactResponse.all.count
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(Contact.all.select('contactee_id, contactor_id, duration, system, contact_campaign_id').as_json).to eq(contact_hash)
      expect(ContactResponse.all.count).to eq(cr_count)
    end

    it 'should correctly save Survey Results' do
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      contact_response = ContactCampaign.last.contact_response_keys.find_by(key: 'voting_intention').contact_responses.first
      expect(contact_response.value).to eq('yes')
      contact_response = ContactCampaign.last.contact_response_keys.find_by(key: 'favorite_party').contact_responses.first
      expect(contact_response.value).to eq('no')
      expect(Contact.first.contact_responses.count).to eq(3)
    end

    it 'should correctly not duplicate Survey Results' do
      ## Create the members
      campaign_contact_member1 = UpsertMember.call(
        {
          firstname: "Bob1",
          phones: [{ phone: "61427700401" }]
        },
        entry_point: "#{IdentitySpoke::SYSTEM_NAME}:test",
      )
      campaign_contact_member2 = UpsertMember.call(
        {
          firstname: "Bob2",
          phones: [{ phone: "61427700402" }]
        },
        entry_point: "#{IdentitySpoke::SYSTEM_NAME}:test",
      )
      campaign_contact_member3 = UpsertMember.call(
        {
          firstname: "Bob3",
          phones: [{ phone: "61427700403" }]
        },
        entry_point: "#{IdentitySpoke::SYSTEM_NAME}:test",
      )
      user_member = UpsertMember.call(
        {
          firstname: @spoke_user.first_name,
          phones: [{ phone: @spoke_user.cell.sub(/^[+]*/,'') }]
        },
        entry_point: "#{IdentitySpoke::SYSTEM_NAME}:test",
      )
      ## Create the campaign
      contact_campaign = FactoryBot.create(
        :contact_campaign,
        name: @spoke_campaign.title,
        external_id: @spoke_campaign.id
      )
      ## Create the contacts
      contact1 = FactoryBot.create(
        :contact,
        external_id: 1,
        contactee: campaign_contact_member1,
        contactor: user_member
      )
      contact2 = FactoryBot.create(
        :contact,
        external_id: 2,
        contactee: campaign_contact_member2,
        contactor: user_member
      )
      contact3 = FactoryBot.create(
        :contact,
        external_id: 3,
        contactee: campaign_contact_member3,
        contactor: user_member
      )
      ## Create the contact response keys
      contact_response_key1 = FactoryBot.create(
        :contact_response_key,
        key: @interaction_step1.question,
        contact_campaign: contact_campaign
      )
      contact_response_key2 = FactoryBot.create(
        :contact_response_key,
        key: @interaction_step2.question,
        contact_campaign: contact_campaign
      )
      ## Create the contact responses
      3.times do |n|
        n += 1
        FactoryBot.create(:contact_response, contact_response_key: contact_response_key1, value: 'yes', contact: eval("contact#{n}"))
        FactoryBot.create(:contact_response, contact_response_key: contact_response_key2, value: 'no', contact: eval("contact#{n}"))
        FactoryBot.create(:contact_response, contact_response_key: contact_response_key2, value: 'maybe', contact: eval("contact#{n}"))
      end

      spoke_assignment = IdentitySpoke::Assignment.first
      campaign_contact = IdentitySpoke::CampaignContact.first
      FactoryBot.create(
        :spoke_message_delivered,
        id: 123456,
        created_at: @time,
        assignment: spoke_assignment,
        campaign_contact_id: campaign_contact.id,
        contact_number: campaign_contact.cell,
        user_id: @spoke_user.id,
        user_number: @spoke_user.cell,
      )

      IdentitySpoke.fetch_new_messages(@sync_id) {}
      expect(ContactResponse.count).to eq(9)
    end

    it 'should update the last_created_at' do
      old_created_at = Sidekiq.redis { |r| r.get 'spoke:messages:last_created_at' }
      sleep 2
      spoke_assignment = FactoryBot.create(
        :spoke_assignment,
        user: @spoke_user,
        campaign: @spoke_campaign
      )
      campaign_contact = FactoryBot.create(
        :spoke_campaign_contact,
        first_name: 'BobNo',
        cell: '+61427700408',
        campaign: @spoke_campaign,
        assignment: spoke_assignment
      )
      message = FactoryBot.create(
        :spoke_message_delivered,
        id: IdentitySpoke::Message.maximum(:id).to_i + 1,
        created_at: @time,
        send_status: 'DELIVERED',
        assignment: spoke_assignment,
        campaign_contact_id: campaign_contact.id,
        contact_number: campaign_contact.cell,
        user_id: @spoke_user.id,
        user_number: @spoke_user.cell
      )
      IdentitySpoke.fetch_new_messages(@sync_id) {}
      new_created_at = Sidekiq.redis { |r| r.get 'spoke:messages:last_created_at' }
      expect(new_created_at).not_to eq(old_created_at)
    end
  end

  context 'fetching new opt outs' do

    before(:all) do
      Sidekiq::Testing.inline!
    end

    after(:all) do
      Sidekiq::Testing.fake!
    end

    before(:each) do
      clean_external_database
      $redis.reset
      @sync_id = 1
      @subscription = FactoryBot.create(:sms_subscription)
      Settings.stub_chain(:spoke, :subscription_id) { @subscription.id }
      Settings.stub_chain(:spoke, :push_batch_amount) { nil }
      Settings.stub_chain(:spoke, :pull_batch_amount) { nil }
      @time = Time.now - 120.seconds
      @spoke_organization = FactoryBot.create(:spoke_organization)
      @spoke_campaign = FactoryBot.create(:spoke_campaign, title: 'Test', organization: @spoke_organization)
      @spoke_user = FactoryBot.create(:spoke_user)
    end

    it 'should opt out people that need it' do
      member = FactoryBot.create(:member, title: 'BobNo')
      member.update_phone_number('61427700409')
      member.subscribe_to(@subscription)
      expect(member.is_subscribed_to?(@subscription)).to eq(true)
      spoke_assignment = FactoryBot.create(
        :spoke_assignment,
        user: @spoke_user,
        campaign: @spoke_campaign
      )
      campaign_contact = FactoryBot.create(
        :spoke_campaign_contact,
        first_name: 'BobNo',
        cell: '+61427700409',
        campaign: @spoke_campaign,
        assignment: spoke_assignment
      )
      spoke_opt_out = FactoryBot.create(
        :spoke_opt_out,
        cell: campaign_contact.cell,
        organization: @spoke_organization,
        assignment: spoke_assignment
      )
      message = FactoryBot.create(
        :spoke_message_delivered,
        id: IdentitySpoke::Message.maximum(:id).to_i + 1,
        created_at: @time,
        assignment: spoke_assignment,
        send_status: 'DELIVERED',
        contact_number: campaign_contact.cell,
        campaign_contact_id: campaign_contact.id,
        user_id: @spoke_user.id,
        user_number: @spoke_user.cell
      )
      IdentitySpoke.fetch_new_opt_outs(@sync_id) {}
      member.reload
      expect(member.is_subscribed_to?(@subscription)).to eq(false)
    end
  end

  context '#fetch_active_campaigns' do

    before(:all) do
      Sidekiq::Testing.inline!
    end

    after(:all) do
      Sidekiq::Testing.fake!
    end

    before(:each) do
      clean_external_database
      @sync_id = 1
      spoke_organization = FactoryBot.create(:spoke_organization)
      2.times do
        spoke_campaign = FactoryBot.create(:spoke_campaign, is_started: true, is_archived: false, title: 'Test', organization: spoke_organization)
        FactoryBot.create(:spoke_interaction_step, campaign: spoke_campaign, question: 'attend')
        FactoryBot.create(:spoke_interaction_step, campaign: spoke_campaign, question: 'volunteer')
      end
      archived_spoke_campaign = FactoryBot.create(:spoke_campaign, is_started: true, is_archived: true, title: 'Test', organization: spoke_organization)
      FactoryBot.create(:spoke_interaction_step, campaign: archived_spoke_campaign, question: 'barnstorm')
      unstarted_spoke_campaign = FactoryBot.create(:spoke_campaign, is_started: false, is_archived: true, title: 'Test', organization: spoke_organization)
      FactoryBot.create(:spoke_interaction_step, campaign: unstarted_spoke_campaign, question: 'calling_party')
    end

    it 'should create contact_campaigns' do
      IdentitySpoke.fetch_active_campaigns(@sync_id) {}
      expect(ContactCampaign.count).to eq(2)
      ContactCampaign.all.each do |campaign|
        expect(campaign).to have_attributes(
          name: 'Test',
          system: IdentitySpoke::SYSTEM_NAME,
          contact_type: IdentitySpoke::CONTACT_TYPE
        )
      end
    end

    it 'should create contact_response_keys' do
      IdentitySpoke.fetch_active_campaigns(@sync_id) {}
      expect(ContactResponseKey.count).to eq(4)
      expect(ContactResponseKey.where(key: 'attend').count).to eq(2)
      expect(ContactResponseKey.where(key: 'volunteer').count).to eq(2)
      expect(ContactResponseKey.where(key: 'barnstorm').count).to eq(0)
      expect(ContactResponseKey.where(key: 'calling_party').count).to eq(0)
    end
  end
end
