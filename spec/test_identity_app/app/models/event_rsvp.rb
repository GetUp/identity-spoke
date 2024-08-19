# == Schema Information
#
# Table name: event_rsvps
#
#  id         :integer          not null, primary key
#  event_id   :integer
#  member_id  :integer
#  created_at :datetime
#  updated_at :datetime
#  deleted_at :datetime
#

class EventRsvp < ApplicationRecord
  belongs_to :event
  belongs_to :member

  after_save :queue_send_to_act, if: :can_send_to_act?

  def can_send_to_act?
    Settings.act.sync_rsvp_to_act && data["system"] != 'act'
  end

  def queue_send_to_act
    SendEventRsvpWorker.perform_async(self.id)
  end

  def send_to_act
    payload = {
      apikey: Settings.act.api_key,
      email: member.email,
      name: member.first_name,
      last_name: member.last_name,
      campaign_id: event.external_id,
      phone: member.phone,
      postal_code: member.address.present? ? member.address.postcode : ''
    }
    url = Settings.act.url
    headers = {
      'Content-Type' => 'multipart/form-data',
    }
    response = Faraday.post(
      url,
      payload,
      headers
    )
    raise StandardError, "Act API returned error HTTP #{response.status}" unless response.success?
  end

  scope :with_guests, -> {
    where("(data ->> 'guests_count')::integer > 0")
  }

  class << self
    def create_rsvp(payload)
      raise ArgumentError.new('No request payload') unless payload

      unless (
        event = (
          payload[:event][:id] ?
          Event.find(payload[:event][:id]) :
          Event.find_by(external_id: payload[:event][:external_id], technical_type: payload[:event][:technical_type])
        )
      )
        raise "RSVP failed to save because event #{payload[:event].inspect} doesn't exist"
      end

      rsvp = payload[:rsvp]

      if rsvp.key?(:member_id)
        unless (member = Member.find(payload[:rsvp][:member_id]))
          raise "RSVP failed to save because the member #{payload[:rsvp][:member_id]} doesn't exist"
        end
      end

      if !member
        member_hash = {
          emails: [{
            email: payload[:rsvp][:email]
          }],
          firstname: payload[:rsvp][:first_name],
          lastname: payload[:rsvp][:last_name],
          addresses: payload[:rsvp][:addresses] ? payload[:rsvp][:addresses] : [],
          custom_fields: payload[:rsvp][:custom_fields] ? payload[:rsvp][:custom_fields] : []
        }

        unless (member = UpsertMember.call(member_hash, entry_point: "event_rsvp_#{event.id}"))
          raise "RSVP failed to save because the member #{member_hash[:email]} doesn't exist and couldn't be created from the payload"
        end
      end

      unless (event_rsvp = EventRsvp.find_or_initialize_by(member: member, event: event))
        raise "RSVP could not be found or created #{payload}"
      end

      if rsvp.key?(:attended)
        event_rsvp.attended = payload[:rsvp][:attended]
      end

      event_rsvp.save!
    end

    def remove_rsvp(payload)
      if (
        event = Event.find_by(
          external_id: payload[:event][:external_id],
          technical_type: payload[:event][:technical_type],
        )
      )
        if (member = Member.find_by(email: payload[:rsvp][:email]))
          EventRsvp.find_by(event_id: event.id, member_id: member.id).try(:destroy)
        end
      end
    end

    def load_from_csv(row)
      if (event = Event.find_by(controlshift_event_id: row['event_id']))
        if (member = UpsertMember.call({ emails: [{ email: row['email'] }] }, firstname: row['first_name'], lastname: row['last_name'], entry_point: "event_rsvp_#{event.id}"))
          event_rsvp = EventRsvp.find_or_initialize_by({
                                                         event_id: event.id,
                                                         member_id: member.id
                                                       })
          event_rsvp.created_at ||= row['created_at']
          event_rsvp.deleted_at = (row['attending_status'] == 'not_attending' ? row['created_at'] : nil)
          event_rsvp.save!
        else
          logger.info("Couldn't create event RSVP as the member was invalid - row ID #{row['id']}")
        end
      else
        logger.info("Couldn't create event RSVP as we don't have the event yet - event ID #{row['event_id']}")

        raise Controlshift::SilentRetryError, "Couldn't create event RSVP as we don't have the event yet"
      end
    end
  end
end
