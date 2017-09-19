# frozen_string_literal: true

require 'kafka/pending_message'
require 'kafka/compressor'
require 'kafka/producer'

# for out_kafka_buffered
module Kafka
  class Producer
    def produce2(value, topic:)
      create_time = Time.now

      message = PendingMessage.new(
        value,
        nil,
        topic,
        nil,
        nil,
        create_time
      )

      @target_topics.add(topic)
      @pending_message_queue.write(message)

      nil
    end
  end
end
