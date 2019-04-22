class ContactResponse < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
  belongs_to :contact
  belongs_to :contact_response_key
end
