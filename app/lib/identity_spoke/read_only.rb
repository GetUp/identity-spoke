module IdentitySpoke
  class ReadOnly < ApplicationRecord
    self.abstract_class = true
    establish_connection Settings.spoke.read_only_database_url if Settings.spoke.read_only_database_url
  end
end
