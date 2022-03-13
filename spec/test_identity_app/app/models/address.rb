# == Schema Information
#
# Table name: addresses
#
#  id         :integer          not null, primary key
#  member_id  :integer
#  line1      :text
#  line2      :text
#  town       :text
#  postcode   :text
#  country    :text
#  created_at :datetime
#  updated_at :datetime
#

class Address < ApplicationRecord

  belongs_to :member
  belongs_to :canonical_address, optional: true

  def display
    as_json.slice('line1', 'line2', 'town', 'state', 'postcode', 'country').map { |_k, v| v }.select(&:present?).join(', ')
  end
end
