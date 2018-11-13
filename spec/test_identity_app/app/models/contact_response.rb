class ContactResponse < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :contact
  belongs_to :contact_response_key
end
