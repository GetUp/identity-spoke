module IdentitySpoke
  class User < ReadOnly
    self.table_name = "user"
    has_many :assignment
    has_many :message
  end
end
