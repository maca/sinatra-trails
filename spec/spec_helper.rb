require 'rubygems'
require 'rspec'
require 'rack/test'

$:.unshift File.join(File.dirname( __FILE__), '..', 'lib') 

require 'trails'

RSpec::Matchers.define :match_route do |expected|
  match do |actual|
    expected.match actual
  end

  description do
    "should match route #{expected}"
  end
end
