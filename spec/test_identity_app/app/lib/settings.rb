# This patch allows accessing the settings hash with dot notation
class Hash
  def method_missing(method, *opts)
    m = method.to_s
    if m == 'opt_out_subscription_id'
      return Subscription::SMS_SUBSCRIPTION.id
    end
    if key?(m)
      return self[m]
    end

    super
  end
end

class Settings
  def self.app
    return {
      "inbound_url" => 'http://localhost',
    }
  end

  def self.spoke
    return {
      "database_url" => ENV['SPOKE_DATABASE_URL'],
      "read_only_database_url" => ENV['SPOKE_READ_ONLY_DATABASE_URL'],
      "opt_out_subscription_id" => nil, # See above
      "push_batch_amount" => 10,
      "pull_batch_amount" => 10,
    }
  end

  def self.redis_url
    return ENV['REDIS_URL']
  end

  def self.redis
    return {
      "pool_size" => 5,
    }
  end

  def self.sidekiq_redis_url
    return ENV['REDIS_URL']
  end

  def self.sidekiq_redis_pool_size
    return 5
  end

  def self.sidekiq
    return {
      "log_level" => "WARN",
      "unique_jobs_debug" => false,
      "unique_jobs_reaper_type" => 'none',
      "unique_jobs_reaper_count" => 100,
      "unique_jobs_reaper_interval" => 30,
      "unique_jobs_reaper_timeout" => 2,
      "unique_jobs_reaper_resurrector_interval" => 1800
    }
  end

  def self.deduper
    return {
      "enabled" => false
    }
  end

  def self.options
    return {
      "default_member_opt_in_subscriptions" => false,
      "allow_subscribe_via_upsert_member" => true,
      "default_phone_country_code" => '61',
      "default_mobile_phone_national_destination_code" => '4',
      "ignore_name_change_for_donation" => true
    }
  end
end
