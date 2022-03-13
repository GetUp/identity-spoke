class Event < ApplicationRecord
  has_many :event_rsvps
  has_many :members, through: :event_rsvps
  belongs_to :host, class_name: 'Member', foreign_key: 'host_id', optional: true
  validates_presence_of :name

  class << self
    def upsert(payload)
      event = Event.find_by(
        external_id: payload[:event][:external_id],
        technical_type: payload[:event][:technical_type]
      )

      event_payload = payload[:event]

      if event_payload[:host_email]
        member_hash = {
          emails: [{
            email: event_payload[:host_email]
          }]
        }
        member_hash = member_hash.merge(event_payload[:host]) if event_payload[:host]

        host = Member.upsert_member(member_hash)
        event_payload[:host_id] = host.id
      end

      payload_with_valid_attributes = event_payload.select { |x| Event.attribute_names.index(x.to_s) }

      if event
        event.update! payload_with_valid_attributes
      else
        Event.create! payload_with_valid_attributes
      end

      EventRsvp.create_rsvp(payload) if payload[:rsvp]
    end
  end
end
