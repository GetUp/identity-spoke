class ContactResponseKey < ApplicationRecord
  belongs_to :contact_campaign, optional: true
  has_many :contact_responses
end
