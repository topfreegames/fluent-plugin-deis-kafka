# frozen_string_literal: true

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end
require 'simplecov'
SimpleCov.start
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'fluent/test'
unless ENV.key?('VERBOSE')
  nulllogger = Object.new
  nulllogger.instance_eval do |_obj|
    def method_missing(method, *args); end # rubocop:disable MethodMissing
  end
  $log = nulllogger # rubocop:disable GlobalVars
end

require 'fluent/plugin/out_deis'

class Test::Unit::TestCase # rubocop:disable ClassAndModuleChildren
end
