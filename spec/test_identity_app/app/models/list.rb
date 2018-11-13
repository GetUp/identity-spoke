class List < ApplicationRecord
  include ReadWriteIdentity
  has_many :list_members
end
