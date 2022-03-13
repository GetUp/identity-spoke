source 'https://rubygems.org'

gemspec
gem 'rails', '~> 6.1.0'
gem 'pg'
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
  gem 'rubocop', require: false
  gem 'pry'
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'spring-commands-rspec'

  # Identity requirements
  gem 'sidekiq'
  gem 'sidekiq-batch'
  gem 'sidekiq-limit_fetch'
  gem 'sidekiq-unique-jobs'
  gem 'zip'
end
