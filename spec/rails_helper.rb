# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

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
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

require 'sidekiq/testing'
Sidekiq::Testing.fake!

# Use fake redis instance for tests
require 'fakeredis/rspec'
require 'action_cable/testing/rspec'
require 'cancan/matchers'

RSpec.configure do |config|
  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Access Warden/Devise authentication methods
  config.include Warden::Test::Helpers

  config.include ApiHelper, json: true
  config.include JsonHeaders, json: true
  config.include SessionHelper

  # Database Cleaner Configuration
  # See: http://www.virtuouscode.com/2012/08/31/configuring-database_cleaner-with-rails-rspec-capybara-and-selenium/
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    # NOTE: need to reindex every searchable model before test suite is run
    Searchkick.models.each(&:reindex)
    Searchkick.disable_callbacks
  end

  config.around(:each, search: true) do |example|
    Searchkick.callbacks(true) do
      example.run
    end
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, auth: true) do
    log_in_as_user
  end

  # `create_org` only makes sense within specs also tagged `auth`
  config.before(:each, create_org: true) do
    # @user from `log_in_as_user` above
    create_org_for_user(@user)
  end

  config.before(:each, truncate: true) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.before(:each) do
    # TODO: Replace this mock once we move firestore into sidekiq jobs
    fake_client = double('firestore')
    fake_methods = Hashie::Mash.new(
      batch: {},
    )
    allow(fake_client).to receive(:write)
    allow(fake_client).to receive(:read)
    allow(fake_client).to receive(:client).and_return(fake_methods)
    allow(FirestoreClient).to receive(:new).and_return(fake_client)
  end

  config.after(:each) do
    DatabaseCleaner.clean
    Warden.test_reset!
    # RedisService.instance.redis.flushdb
  end

  # Use create, build, etc instead of FactoryBot prefix
  # https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#using-factories
  config.include FactoryBot::Syntax::Methods

  # RSpec.configure do |c|
  #   c.example_status_persistence_file_path = "tmp/rspec_failures.txt"
  #   c.run_all_when_everything_filtered = true
  # end
end

# better readability and ability to chain "not changes"
RSpec::Matchers.define_negated_matcher :not_change, :change

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
