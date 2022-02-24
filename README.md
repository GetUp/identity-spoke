# Identity Spoke

A rails engine which integrates with Identity to facilitate bi-direction data flow between [Identity](https://github.com/the-open/identity) and [Spoke](https://github.com/getup/spoke).

Created and maintained by [GetUp!](https://getup.org.au)

---

These instructions should get you up and running with Identity Spoke gem locally for development and testing. 

### Local Development

When developing this engine alongside Identity you'll need to reference where to find the local repository to identity bundler.
- From within the host identity app `cd /path/to/identity`
- Setup bundle reference to the local repo `bundle config --local local.identity_spoke /path/to/identity_spoke`
- When you're done unset `bundle config --delete local.identity_spoke`

## System dependencies

### PostgreSQL
OSX:
- You can use [Postgres.app](https://postgresapp.com/) (which is simpler to upgrade than a homebrew install). Note: this allows you to connect to Postgres locally without an empty username and password.

Linux:
- `sudo apt-get install postgresql libpq-dev`
- `sudo -u postgres psql -c "create role username with SUPERUSER login password 'password'"`, replacing _`username`_ and _`password`_ with the ones you want to use for the app.

### Ruby
Install the version of Ruby referenced in the [Gemfile](./Gemfile#L3) using a version manager/installer like [chruby](https://github.com/postmodern/chruby) and [ruby-install](https://github.com/postmodern/ruby-install)

## Project setup and configuration
These commands assume you're in the project directory, and have the right version of ruby in your path.
- Checkout the project from git
- Install bundler: `gem install bundler`
- Install project dependencies: `bundle install`
- Copy [`.env.development.sample`](./.env.development.sample) to `.env.development`, and populate the required settings

## Running the test suite
- Copy [`spec/test_identity_app/.env.test.sample`](./spec/test_identity_app/.env.test.sample) to `spec/test_identity_app/.env.test`, and update the `DATABASE_URL`
- Create a test database: `createdb identity_spoke_test_host; RAILS_ENV=test bundle exec rake db:migrate`
- `bundle exec rspec` runs all the tests
