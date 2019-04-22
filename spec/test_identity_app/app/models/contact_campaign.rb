class ContactCampaign < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
  has_many :contact_response_keys
  has_many :contacts
end
