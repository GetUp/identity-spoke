require 'dotenv'
Dotenv.load

require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Identity
  VERSION = '22.06'.freeze

  class Application < Rails::Application
    class ExceptionHandlerMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue ActionController::BadRequest => e
        # handle malformed requests -- we don't want newrelic/airbrake/... flooded
        # with errors caused by client bugs
        return [400, { "Content-Type" => "text/plain" }, [e.to_s]]
      end
    end

    private_constant :ExceptionHandlerMiddleware

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Disabled protected attributes for now, this allows us to continue
    # using weak params, until we refactor and move to strong params
    config.action_controller.permit_all_parameters = true

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    config.generators do |g|
      g.assets false
      g.helper false
    end

    # Ensure locale doesn't leak between requests in multi-threaded envrionments.
    # See: https://github.com/svenfuchs/i18n/pull/382
    config.middleware.use ::I18n::Middleware

    # Load app settings
    require_relative '../app/lib/settings'

    config.middleware.use ExceptionHandlerMiddleware
  end
end
