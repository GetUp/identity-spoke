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
      "read_only_database_url" => ENV['SPOKE_DATABASE_URL'],
      "opt_out_subscription_id" => Subscription::SMS_SUBSCRIPTION,
      "push_batch_amount" => nil,
      "pull_batch_amount" => nil,
    }
  end

  def self.options
    return {
      "default_phone_country_code" => '61',
      "ignore_name_change_for_donation" => true
    }
  end
end
