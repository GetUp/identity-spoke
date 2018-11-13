module IdentitySpoke
  module ReadWrite
    def self.included(mod)
      mod.establish_connection Settings.spoke.database_url if Settings.spoke.database_url
    end
  end
end