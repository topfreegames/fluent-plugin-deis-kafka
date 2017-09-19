# frozen_string_literal: true

require 'helper'
require 'fluent/test/driver/output'
require 'fluent/plugin/output'
require 'kafka'

class KafkaOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    @valid_router_log = {
      'kubernetes' => { 'container_name' => 'deis-router' },
      'log' => "[2016-05-31T16:56:12+00:00] - foo - 10.2.1.1 - - - 200 - \"GET / HTTP/1.0\" - 211 - - - \"ApacheBench/2.3\" - \"~^foo\\x5C.(?<domain>.+)$\" - 10.1.1.4:80 - foo.bar.io - 0.002 - 0.046\n" # rubocop:disable LineLength
    }

    @deis_output = create_driver
  end

  BASE_CONFIG = %(
    type deis
  )

  CONFIG = BASE_CONFIG + %(
    brokers localhost:9092
  )

  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::Driver::Output.new(Fluent::Plugin::DeisOutput).configure(conf)
  end

  def test_configure
    assert_nothing_raised(Fluent::ConfigError) do
      create_driver(BASE_CONFIG)
    end

    assert_nothing_raised(Fluent::ConfigError) do
      create_driver(CONFIG)
    end

    assert_nothing_raised(Fluent::ConfigError) do
      create_driver(CONFIG + %(
        buffer_type memory
      ))
    end

    d = create_driver
    assert_equal 'metrics', d.instance.metrics_topic
    assert_equal 'localhost:9092', d.instance.brokers
  end

  def test_write
    d = create_driver
    d.run(default_tag: 'test') do
      d.feed(@valid_router_log)
    end

    kafka = Kafka.new(seed_brokers: ['localhost:9092'])

    kafka.each_message(topic: 'metrics') do |message|
      assert_true(message.value.include?('deis_router_request_time_ms,app=foo,status_code=200 value=0.046'))
      assert_true(message.value.include?('deis_router_response_time_ms,app=foo,status_code=200 value=0.002'))
      assert_true(message.value.include?('deis_router_bytes_sent,app=foo,status_code=200 value=211.0'))
      break
    end
  end

  def test_deis_parse_router_message_should_return_valid_map
    router_metrics = @deis_output.instance.parse_router_log(@valid_router_log['log'], 'some.new.host')
    assert_true(router_metrics['app'] == 'foo')
    assert_true(router_metrics['status_code'] == '200')
    assert_true(router_metrics['bytes_sent'] == 211.0)
    assert_true(router_metrics['response_time'] == 0.002)
    assert_true(router_metrics['request_time'] == 0.046)
    assert_true(router_metrics['host'] == 'some.new.host')
  end
end
