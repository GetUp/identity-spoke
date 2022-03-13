# == Schema Information
#
# Table name: area_memberships
#
#  id         :integer          not null, primary key
#  area_id    :integer
#  member_id  :integer
#  created_at :datetime
#  updated_at :datetime
#

class AreaMembership < ApplicationRecord
  belongs_to :member
  belongs_to :area
end
