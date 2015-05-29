# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'web_task_runner/version'

Gem::Specification.new do |spec|
  spec.name          = "web_task_runner"
  spec.version       = WebTaskRunner::VERSION
  spec.authors       = ["Neson"]
  spec.email         = ["neson@dex.tw"]

  spec.summary       = %q{Web wrapper to run a specific task.}
  spec.description   = %q{Web wrapper to run a specific task with Sidekiq. Provides HTTP API to start, stop, get status of the task running in background, and is deployable to cloud platforms like Heroku.}
  spec.homepage      = "http://github.com/Neson/web_task_runner"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Web framework and server
  spec.add_dependency "sinatra", "~> 1.4.6"
  spec.add_dependency "thin"

  # Job runner
  spec.add_dependency "sidekiq", "~> 3.3.4"
  spec.add_dependency "sidekiq-status"

  # Utilities
  spec.add_dependency "dotenv"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
end
