# Identity Spoke

A rails engine which integrates with Identity to facilitate
bi-direction data flow between
[Identity](https://github.com/the-open/identity) and
[Spoke](https://github.com/StateVoicesNational/Spoke).

Created and maintained by [GetUp!](https://getup.org.au)

---

These instructions should get you up and running with Identity Spoke
gem locally for development and testing.

### Local Development

When developing this engine, you'll need a local development instance
of Identity set up and this repo added as local dependency of that:

 * From within the host identity app `cd /path/to/identity`
 * Setup bundle reference to the local repo `bundle config --local
   local.identity_spoke /path/to/identity_spoke`
 * When you're done unset `bundle config --delete local.identity_spoke`

Once installed this way, you can start the local development instance
to run your changes here.

## System dependencies

 * Ruby
 * Postgres
 * Redis

## Project setup and configuration

These commands assume you're in the project directory, and have the
right version of ruby in your path.

 * Checkout the project from git
 * Install bundler: `gem install bundler`
 * Install project dependencies: `bundle install`

## Running the test suite

- Copy [`spec/test_identity_app/.env.test.sample`](./spec/test_identity_app/.env.test.sample)
  to `spec/test_identity_app/.env.test`, and update `DATABASE_URL`
- Create a test database: `RAILS_ENV=test bundle exec rake db:setup`
- `bundle exec rspec` runs all the tests
