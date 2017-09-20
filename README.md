# fluentd-plugin-deis-kafka
[![Build Status](https://travis-ci.org/topfreegames/fluent-plugin-deis-kafka.svg?branch=master)](https://travis-ci.org/topfreegames/fluent-plugin-deis-kafka) [![Dependency Status](https://gemnasium.com/badges/github.com/topfreegames/fluent-plugin-deis-kafka.svg)](https://gemnasium.com/github.com/topfreegames/fluent-plugin-deis-kafka) [![Gem Version](https://badge.fury.io/rb/fluent-plugin-deis-kafka.svg)](https://badge.fury.io/rb/fluent-plugin-deis-kafka)

Fluent output plugin to send deis-router metrics to kafka, to later be consumed by telegraf.

## install

`gem install fluent-plugin-deis-kafka`

## usage

```
<match **>
  @type deis
  brokers broker-1:9092,broker2:9092
  compression_codec snappy
  required_acks 1
</match>
```

## parameters
````
:brokers, default: 'localhost:9092'
:client_id, default: 'fluentd'
:metrics_topic, default: 'metrics'
:discard_kafka_delivery_failed, default: false

# ruby-kafka producer options
:max_send_retries, default: 2
:required_acks,  default: 1
:ack_timeout, default: nil
:compression_codec, default: nil
#The codec the producer uses to compress messages.
#Supported codecs: (gzip|snappy)

:max_send_limit_bytes, default: nil
:kafka_agg_max_bytes, default: 4 * 1024 # 4k
:kafka_agg_max_messages, default: nil
```
