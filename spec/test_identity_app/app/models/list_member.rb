# == Schema Information
#
# Table name: list_members
#
#  id         :integer          not null, primary key
#  list_id    :integer
#  member_id  :integer
#  created_at :datetime
#  updated_at :datetime
#  deleted_at :datetime
#

class ListMember < ApplicationRecord
  belongs_to :member
  belongs_to :list

  validates_uniqueness_of :list_id, scope: [:member_id]
end
