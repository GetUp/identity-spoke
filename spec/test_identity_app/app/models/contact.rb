# == Schema Information
#
# Table name: contacts
#
#  id         :integer          not null, primary key
#  type       :text
#  notes      :text
#  created_at :datetime
#  updated_at :datetime
#

class Contact < ApplicationRecord
  belongs_to :contactor, class_name: 'Member', optional: true
  belongs_to :contactee, class_name: 'Member'
  belongs_to :contact_campaign, optional: true

  has_many :contact_responses

  validates_presence_of :contactee

  # enum contact_type: [:call, :sms, :irl, :letter, :email]
end
