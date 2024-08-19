module IdentitySpoke
  class User < ReadOnly
    self.table_name = "user"
    has_many :assignment, dependent: nil
    has_many :message, dependent: nil
  end
end
