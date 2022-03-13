class ContactResponseKey < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
    
  belongs_to :contact_campaign
  has_many :contact_responses
end
