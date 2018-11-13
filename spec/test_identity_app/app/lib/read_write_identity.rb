module ReadWriteIdentity
  def self.included(mod)
    mod.establish_connection ENV['DATABASE_URL']
  end
end