# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# This is normally done as part of Rails boot. We need it earlier in test to
# ensure ENV['DATABASE_URL'] is set so we cab infer external database URLs next
require 'dotenv'
Dotenv.load('spec/test_identity_app/.env.test')

# Load rails
require File.expand_path('../test_identity_app/config/environment', __FILE__)
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

# Setup sidekiq for fake queuing of jobs by default
# https://github.com/mperham/sidekiq/wiki/Testing#testing-worker-queueing-fake
require 'sidekiq/testing'
Sidekiq::Testing.fake!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

# Turn off Redshift because this creates problems with transactions
RedshiftDB = ActiveRecord::Base

require 'database_cleaner/active_record'

RSpec.configure do |config|
  config.fixture_path = "#{Rails.root}/spec/fixtures"

  config.before(:suite) do
    # Use 'truncation' for the strategy instead of 'transaction' for
    # all cleaners below because although truncation is slower, the
    # transaction strategy causes negative interactions between
    # fixtures created and the test code.
    #
    # In particular, Identity Subscription::FOO_SUBSCRIPTION instances
    # are lazily populated - deleting the rows for those in the DB can
    # cause the id of the older versions to be inconsistent with those
    # in the DB.
    #
    # Also, local IdentitySpoke classes that use the ReadWrite model
    # and the ReadOnly model use different database connections, and
    # this means that when creating fixtures the DatabaseCleaner's
    # transactions hide objects created from the other.

    DatabaseCleaner[:active_record].strategy = [
      :truncation, except: ['subscriptions', 'settings']
    ]
    DatabaseCleaner[:active_record].clean_with(:truncation)

    DatabaseCleaner[
      :active_record,
      db: IdentitySpoke::ReadWrite
    ].strategy = :truncation
    DatabaseCleaner[
      :active_record,
      db: IdentitySpoke::ReadWrite
    ].clean_with(:truncation)

    DatabaseCleaner[
      :active_record,
      db: IdentitySpoke::ReadOnly
    ].strategy = :truncation
    DatabaseCleaner[
      :active_record,
      db: IdentitySpoke::ReadOnly
    ].clean_with(:truncation)

    DatabaseCleaner[:redis].strategy = :deletion
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      # Allow individual specs to do this when they need to via a method in
      # auth_helpers, which could also run `FactoryBot.create(:member_admin)`
      #Role.create!(description: 'Admin')
      # Subscriptions that are assumed to exist for many tests
      #[:email, :sms, :notification].each do |channel|
      #  FactoryBot.create(:"#{channel}_subscription")
      #end
      #ActiveRecord::Base.connection.execute("ALTER SEQUENCE subscriptions_id_seq RESTART WITH 4;")
      example.run
    end
  end

  config.before(:each) do
    # Clear all (fake) Sidekiq jobs between tests
    Sidekiq::Worker.clear_all
  end

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
