module IdentitySpoke
  class User < ReadOnly
    self.table_name = "user"
    has_many :assignments
  end
end
