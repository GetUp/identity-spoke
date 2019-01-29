# Ensure locale is passed to sidekiq workers
require 'sidekiq/middleware/i18n'

Sidekiq::Extensions.enable_delay!
