source 'https://rubygems.org'

ruby '>= 3.1.6'

gemspec
gem 'rails', '~> 7.0.0'
gem 'pg'
gem 'redis'
gem 'active_model_serializers'

group :development, :test do
  gem 'phony'
  gem 'faker'
  gem 'dotenv-rails'
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails'
  gem 'rspec-mocks'
  gem 'database_cleaner-active_record'
  gem 'database_cleaner-redis'
  gem 'factory_bot_rails'
  gem 'rubocop'
  gem 'rubocop-factory_bot'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  gem 'pry'
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'spring-commands-rspec'

  # Identity requirements
  gem 'sidekiq'
  gem 'sidekiq-batch'
  gem 'sidekiq-limit_fetch'
  gem 'sidekiq-unique-jobs'
  gem 'audited', '~> 5.4.2'
  gem 'zip'
end
