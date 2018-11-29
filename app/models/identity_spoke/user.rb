module IdentitySpoke
  class User < ApplicationRecord
    self.table_name = "user"
    include ReadOnly
    has_many :assignments
  end
end
