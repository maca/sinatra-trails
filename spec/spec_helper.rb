require 'rubygems'
require 'rspec'
require 'rack/test'

$:.unshift File.join(File.dirname( __FILE__), '..', 'lib') 

require 'sinatra/trails'
