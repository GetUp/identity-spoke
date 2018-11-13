class ListMember < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :list
  belongs_to :member
end
