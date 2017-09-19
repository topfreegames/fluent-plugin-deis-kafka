# frozen_string_literal: true

require 'fluent/mixin/config_placeholders'
require 'fluent/mixin/plaintextformatter'
require 'fluent/mixin/rewrite_tag_name'
require 'fluent/mixin/deis'
require 'fluent/plugin/output'
require 'influxdb'

module Fluent::Plugin
  class DeisOutput < Output
    Fluent::Plugin.register_output('deis', self)

    include Fluent::Mixin::PlainTextFormatter
    include Fluent::Mixin::ConfigPlaceholders
    include Fluent::HandleTagNameMixin
    include Fluent::Mixin::RewriteTagName
    include Fluent::Mixin::Deis
    config_param :brokers, :string, default: 'localhost:9092',
                                    desc: <<-DESC
                                     Set brokers directly:
                                     <broker1_host>:<broker1_port>,<broker2_host>:<broker2_port>,..
                                    DESC
    config_param :client_id, :string, default: 'fluentd'
    config_param :metrics_topic, :string, default: 'metrics'
    config_param :discard_kafka_delivery_failed, :bool, default: false

    # ruby-kafka producer options
    config_param :max_send_retries, :integer, default: 2,
                                              desc: 'Number of times to retry '\
                                              'sending of messages to a leader.'
    config_param :required_acks, :integer, default: 1,
                                           desc: 'The number of acks required per request.'
    config_param :ack_timeout, :time, default: nil,
                                      desc: 'How long the producer waits for acks.'
    config_param :compression_codec, :string, default: nil,
                                              desc: <<~DESC
                                                The codec the producer uses to compress messages.
                                                Supported codecs: (gzip|snappy)
                                              DESC

    config_param :max_send_limit_bytes, :size, default: nil
    config_param :kafka_agg_max_bytes, :size, default: 4 * 1024 # 4k
    config_param :kafka_agg_max_messages, :integer, default: nil

    define_method('log') { $log } unless method_defined?(:log) # rubocop:disable GlobalVars

    def initialize
      super
      require 'kafka'
      require 'fluent/plugin/kafka_producer_ext'

      @kafka = nil
      @producers = {}
      @producers_mutex = Mutex.new
    end

    def start
      super
      refresh_client
    end

    def shutdown
      super
      shutdown_producers
      @kafka = nil
    end

    def shutdown_producers
      @producers_mutex.synchronize do
        @producers.each_value(&:shutdown)
        @producers = {}
      end
    end

    def get_producer # rubocop:disable AccessorMethodName
      @producers_mutex.synchronize do
        producer = @producers[Thread.current.object_id]
        unless producer
          producer = @kafka.producer(@producer_opts)
          @producers[Thread.current.object_id] = producer
        end
        producer
      end
    end

    def deliver_messages(producer, tag)
      if @discard_kafka_delivery_failed
        begin
          producer.deliver_messages
        rescue Kafka::DeliveryFailed => e
          log.warn 'DeliveryFailed occurred. Discard broken event:',
                   error: e.to_s, error_class: e.class.to_s, tag: tag
          producer.clear_buffer
        end
      else
        producer.deliver_messages
      end
    end

    def refresh_client(raise_error = true)
      @kafka = Kafka.new(seed_brokers: @brokers.split(','), client_id: @client_id)
      log.info "initialized kafka producer: #{@client_id}"
    rescue Exception => e # rubocop:disable RescueException
      raise e if raise_error
      log.error e
    end

    def configure(conf)
      super

      @producer_opts = { max_retries: @max_send_retries, required_acks: @required_acks }
      @producer_opts[:ack_timeout] = @ack_timeout if @ack_timeout
      @producer_opts[:compression_codec] = @compression_codec.to_sym if @compression_codec

      return unless @discard_kafka_delivery_failed
      log.warn "'discard_kafka_delivery_failed' option discards events which "\
               'cause delivery failure, e.g. invalid topic or something.'
      log.warn 'If this is unexpected, you need to check your configuration or data.'
    end

    # def emit(tag, es, chain)
    #   super(tag, es, chain, tag)
    # end

    def filter_record(record)
      return unless from_router?(record)
      data = build_series(record)
      return unless data
      return data.map do |point|
        InfluxDB::PointValue.new(point).dump
      end.join("\n")
    rescue Exception => e # rubocop:disable RescueException
      puts "Error:#{e.backtrace}"
    end

    def write(chunk)
      tag = chunk.metadata.tag
      producer = get_producer

      records_by_topic = {}
      bytes_by_topic = {}
      messages = 0
      messages_bytes = 0
      record_buf = nil
      record_buf_bytes = nil
      begin
        Fluent::Engine.msgpack_factory.unpacker(chunk.open).each do |time, record|
          begin
            topic = @metrics_topic
            records_by_topic[topic] ||= 0
            bytes_by_topic[topic] ||= 0
            line = filter_record(record)

            next unless line
            record_buf_bytes = line.bytesize
            if @max_send_limit_bytes && record_buf_bytes > @max_send_limit_bytes
              log.warn 'record size exceeds max_send_limit_bytes. Skip event:',
                       time: time, record: record
              next
            end
          rescue StandardError => e
            log.warn 'unexpected error during format record. Skip broken event:',
                     error: e.to_s, error_class: e.class.to_s, time: time, record: record
            next
          end

          if messages.positive? &&
             (messages_bytes + record_buf_bytes > @kafka_agg_max_bytes) ||
             (@kafka_agg_max_messages && messages >= @kafka_agg_max_messages)
            log.debug do
              "#{messages} messages send because reaches the limit of batch transmission."
            end
            deliver_messages(producer, tag)
            messages = 0
            messages_bytes = 0
          end

          log.trace do
            "message will send to #{topic} with partition_key: #{partition_key},"\
            "partition: #{partition}, message_key: #{message_key} and value: #{record_buf}."
          end

          messages += 1
          producer.produce2(
            line,
            topic: topic
          )
          messages_bytes += record_buf_bytes

          records_by_topic[topic] += 1
          bytes_by_topic[topic] += record_buf_bytes
        end
        if messages.positive?
          log.debug { "#{messages} messages send." }
          deliver_messages(producer, tag)
        end
        log.debug { "(records|bytes) (#{records_by_topic}|#{bytes_by_topic})" }
      end
    rescue Exception => e # rubocop:disable RescueException
      log.warn "Send exception occurred: #{e}"
      log.warn "Exception Backtrace : #{e.backtrace.join("\n")}"
      # For safety, refresh client and its producers
      shutdown_producers
      refresh_client(false)
      # Raise exception to retry sendind messages
      raise e
    end
  end
end
