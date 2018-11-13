class ContactResponseKey < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :contact_campaign
  has_many :contact_responses
end
