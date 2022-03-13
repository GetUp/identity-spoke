module IdentitySpoke
  class ReadWrite < ApplicationRecord
    self.abstract_class = true
    establish_connection Settings.spoke.database_url if Settings.spoke.database_url
  end
end
