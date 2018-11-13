module IdentitySpoke
  module ReadOnly
    def self.included(mod)
      mod.establish_connection Settings.spoke.read_only_database_url if Settings.spoke.read_only_database_url
    end
  end
end