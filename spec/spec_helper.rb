require 'rubygems'
require 'spec'
require 'spec/mocks'

Spec::Runner.configure do |config|
  # == Mock Framework
  #
  # RSpec uses its own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
end

Spec::Matchers.define :have_same_set do |expected|
  description do
    "have same set of elements than #{expected.inspect}"
  end

  match do |actual|
    actual.to_set == expected.to_set
  end
end
