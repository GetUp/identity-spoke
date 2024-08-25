class ContactResponse < ApplicationRecord
  belongs_to :contact
  belongs_to :contact_response_key
  validates_presence_of :contact
end
