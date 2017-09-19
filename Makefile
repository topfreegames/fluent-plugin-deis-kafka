.PHONY: test
MY_IP?=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1`

test-dep-up:
	@env MY_IP=${MY_IP} docker-compose up -d
test-dep-down:
	@env MY_IP=${MY_IP} docker-compose down

test: test-dep-up
	sleep 10
	@rake test
	$(MAKE) test-dep-down

static:
	@rubocop -ES

test-ci: test static

publish:
	@gem build fluent-plugin-deis-kafka.gemspec
	@gem push fluent-plugin-deis-kafka*.gem
