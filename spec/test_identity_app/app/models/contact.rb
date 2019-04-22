class Contact < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
  belongs_to :contactor, class_name: 'Member', foreign_key: 'contactor_id', optional: true
  belongs_to :contactee, class_name: 'Member', foreign_key: 'contactee_id'
  belongs_to :contact_campaign, optional: true
  has_many :contact_responses
end
