# Ensure locale is passed to sidekiq workers
require 'sidekiq/middleware/i18n'
# Enable killswitch features
require 'sidekiq/killswitch/middleware/load_all'

Sidekiq::Extensions.enable_delay!

Sidekiq.logger.formatter = Sidekiq::Logger::Formatters::Pretty.new
Sidekiq.logger.level = Logger.const_get(Settings.sidekiq.log_level.upcase)

Sidekiq.configure_server do |config|
  config.on(:startup) do
    if Sidekiq.options[:concurrency] > ActiveRecord::Base.connection_pool.size ||
       (Settings.options.use_redshift && Sidekiq.options[:concurrency] > RedshiftDB.connection_pool.size)
      Sidekiq.logger.error "Sidekiq concurrency (worker) count (#{Sidekiq.options[:concurrency]}) exceeds connecton pool for primary (ActiveRecord::Base) or RedshiftDB database, add pool=#{Sidekiq.options[:concurrency]} option to DATABASE_URL and REDSHIFT_URL environment variable. Shutting down Sidekiq!"
      Process.kill('TERM', Process.pid)
    end
  end

  config.redis = { url: Settings.sidekiq_redis_url, size: Settings.sidekiq_redis_pool_size }

  config.super_fetch! if defined?(::Sidekiq::Pro)

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: Settings.sidekiq_redis_url, size: Settings.sidekiq_redis_pool_size }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end

SidekiqUniqueJobs.configure do |config|
  config.lock_ttl        = 60 * 60 * 24 # Expire locks after 24 hours by default
  config.lock_info       = Settings.sidekiq.unique_jobs_debug # true for debugging
  config.max_history     = 1000 # keeps n number of changelog entries
  config.reaper          = Settings.sidekiq.unique_jobs_reaper_type.to_sym # also :lua but that will lock while cleaning
  config.reaper_count    = Settings.sidekiq.unique_jobs_reaper_count # Reap maximum this many orphaned locks
  config.reaper_interval = Settings.sidekiq.unique_jobs_reaper_interval
  config.reaper_timeout  = Settings.sidekiq.unique_jobs_reaper_timeout
  config.reaper_resurrector_enabled = true
  config.reaper_resurrector_interval = Settings.sidekiq.unique_jobs_reaper_resurrector_interval # Don't waste resources restarting the reaper constantly, once an hour is enough

  # This config is important for recovering memory after large sends.
  # At the upper limit, the default config can clean up 2,880,000 digests in 24 hours
  # The single largest producer of orphan digests is mailing sends
  # If, at any point, you might want to send more than 2 million
  # emails in a single 24 hour period, you should consider changing
  # this config, either allowing the reaper to run more frequently (interval)
  # or clean up more jobs per run (count), but be careful, if the reaper
  # starts hitting its timeout a lot, it will fail entirely

  # Also note - the reaper needs to check digests are not contained in
  # sidekiq queues before removing. During sends, queues become extremely
  # large, so the reaper will often hit its timeout (default: 20 seconds)
  # It should recover after the send is finished, and queues return to
  # low numbers (less than 50 per queue)
end

Sidekiq::Client.reliable_push! if defined?(::Sidekiq::Pro)

# Patch Sidekiq logging so that it shows class and method for delayed methods
module Sidekiq
  module Middleware
    module Server
      class Logging
        def call(_worker, item, _queue)
          extra_info = if item['class'] == "Sidekiq::Extensions::DelayedClass"
                         (target, method_name) = YAML.load(item['args'].first)
                         " #{target}##{method_name}"
                       end
          begin
            start = Time.now
            logger.info("start#{extra_info}".freeze)
            yield
            logger.info("done#{extra_info}: #{elapsed(start)} sec")
          rescue StandardError => e
            logger.info("fail#{extra_info}: (message: #{e.message}) #{elapsed(start)} sec")
            raise
          end
        end
      end
    end
  end
end
