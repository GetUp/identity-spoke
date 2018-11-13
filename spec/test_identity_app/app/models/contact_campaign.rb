class ContactCampaign < ApplicationRecord
  include ReadWriteIdentity
  has_many :contact_response_keys
  has_many :contacts
end
