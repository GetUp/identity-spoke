class ContactCampaign < ApplicationRecord
  include Orderable
  include Searchable

  has_many :contacts
  has_many :contact_responses, :through => :contacts
  has_many :contact_response_keys
  has_many :syncs, dependent: :nullify

  belongs_to :member
end
