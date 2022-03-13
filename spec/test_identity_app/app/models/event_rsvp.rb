class EventRsvp < ApplicationRecord
  belongs_to :event
  belongs_to :member

  class << self
    def create_rsvp(payload)
      if (
        event = Event.find_by(
          external_id: payload[:event][:external_id],
          technical_type: payload[:event][:technical_type],
        )
      )
        member_hash = {
          emails: [{
            email: payload[:rsvp][:email]
          }],
          firstname: payload[:rsvp][:first_name],
          lastname: payload[:rsvp][:last_name]
        }

        if (member = Member.upsert_member(member_hash))
          EventRsvp.create!(member: member, event: event)
        else
          logger.info "RSVP failed to save because the member for this RSVP doesn't exist and couldn't be created from the payload"
          false
        end
      else
        logger.info "RSVP failed to save because event #{payload[:event].inspect} doesn't exist"
        false
      end
    end
  end
end
