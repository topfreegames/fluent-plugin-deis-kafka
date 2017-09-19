# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = 'fluent-plugin-deis-kafka'
  gem.version       = '0.2.0'
  gem.authors       = ['Guilherme Souza']
  gem.email         = ['backend@tfgco.com']
  gem.description   = 'Fluentd plugin to send deis-router metrics'\
                      'to influxdb through kafka'
  gem.summary       = 'Fluentd plugin to send deis-router metrics'\
                      'to influxdb through kafka'\
                      'based on: https://github.com/deis/fluentd and https://github.com/fluent/fluent-plugin-kafka'
  gem.homepage      = 'https://github.com/topfreegames/fluent-plugin-deis-kafka'
  gem.license       = 'MIT'

  gem.files         = Dir.glob('{lib}/**/*') + %w[LICENSE README.md]
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
  gem.has_rdoc      = false

  gem.required_ruby_version = '>= 2.0.0'

  gem.add_runtime_dependency 'fluentd', '~> 0.14'
  gem.add_runtime_dependency 'influxdb', '~> 0.4'
  gem.add_runtime_dependency 'ruby-kafka', '~> 0.4.2'

  gem.add_development_dependency 'bundler', '~> 1.3'
  gem.add_development_dependency 'rake', '~> 12.0'
  gem.add_development_dependency 'test-unit', '~> 3.2'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'simplecov'
end
