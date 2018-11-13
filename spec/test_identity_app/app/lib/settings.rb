# This patch allows accessing the settings hash with dot notation
class Hash
  def method_missing(method, *opts)
    m = method.to_s
    return self[m] if key?(m)
    super
  end
end

class Settings
  def self.spoke
    return {
      "database_url" => ENV['SPOKE_DATABASE_URL'],
      "read_only_database_url" => ENV['SPOKE_DATABASE_URL']
    }
  end

  def self.options
    return {
      "default_phone_country_code" => '61'
    }
  end
end
