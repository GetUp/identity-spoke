Sidekiq::Killswitch.configure do |config|
  # Enables Sidekiq Worker class validation in Web UI
  config.validate_worker_class_in_web
end
