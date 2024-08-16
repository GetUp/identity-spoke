# == Schema Information
#
# Table name: events
#
#  id                    :integer          not null, primary key
#  name                  :text
#  start_time            :datetime
#  end_time              :datetime
#  description           :text
#  campaign_id           :integer
#  created_at            :datetime
#  updated_at            :datetime
#  host_id               :integer
#  controlshift_event_id :integer
#  location              :text
#  latitude              :float
#  longitude             :float
#  attendees             :integer
#  group_id              :integer
#  area_id               :integer
#  image_url             :text
#

class Event < ApplicationRecord
  extend Geocoder::Model::ActiveRecord
  include Orderable
  include Searchable

  geocoded_by :location
  reverse_geocoded_by :latitude, :longitude
  after_validation :geocode, if: ->(obj) { obj.location.present? && (obj.latitude.blank? || obj.longitude.blank?) }

  has_many :event_rsvps
  has_many :members, through: :event_rsvps
  belongs_to :campaign
  belongs_to :host, class_name: 'Member', optional: true
  validates_presence_of :name
  belongs_to :area, optional: true

  def rsvp_total
    event_rsvps.length
  end

  def rsvp_guests_total
    event_rsvps.with_guests.sum { |rsvp| rsvp.data.guests_count }
  end

  def rsvp_total_with_guests
    rsvp_total + rsvp_guests_total
  end

  def set_constituency
    if (nearest_zip = Postcode.nearest_postcode(latitude, longitude))
      constituency = Area.find_by!(area_type: 'pcon_new', code: nearest_zip.pcon_new)
      update!(area_id: constituency.id)
    end
  end
  # after_save :set_constituency, if: ->(obj) { obj.latitude.present? and obj.longitude.present? and obj.area_id.blank? }

  class << self
    def find_near_postcode(postcode, radius)
      if (zip = Postcode.search(postcode))
        return near([zip.latitude, zip.longitude], radius)
      end

      []
    end

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

        host = UpsertMember.call(member_hash)
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

    def remove_event(payload)
      if (
        event = Event.find_by(
          external_id: payload[:event][:external_id],
          technical_type: payload[:event][:technical_type],
        )
      )
        event.destroy!
      end
    end

    def load_from_csv(row)
      # create event
      event = Event.find_or_initialize_by(controlshift_event_id: row['id'])
      event.name = row['title']
      event.start_time = row['start_at']
      event.description = row['description']

      # is it linked to a local group?
      unless row['local_chapter_id'].nil?
        event.group_id = row['local_chapter_id']
        if (group = Group.find_by(controlshift_group_id: row['local_chapter_id']))
          group.count_events
        end
      end

      # do we have a location for it?
      if (location = Location.find_by(controlshift_location_id: row['location_id']))
        event.location = location.description
        event.latitude = location.latitude
        event.longitude = location.longitude
      end

      event.created_at = Time.parse(row['created_at'])
      event.save!
    end
  end
end
