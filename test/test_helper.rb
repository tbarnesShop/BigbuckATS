ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Parallel workers need a MySQL pool larger than worker count and the
    # database user must be able to create bigbuck_test-N databases (CI's MySQL
    # user only owns bigbuck_test). Keep a high threshold, so the suite stays
    # serial, until CI grants that and the overhead is worth it.
    parallelize(workers: :number_of_processors, threshold: 1000)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
