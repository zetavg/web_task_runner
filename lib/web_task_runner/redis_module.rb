require 'sinatra'
require 'sidekiq'

class WebTaskRunner < Sinatra::Application
  module RedisModule
    def self.connection
      if ENV['REDIS_NAMESPACE']
        proc { Redis.new(url: ENV['REDIS_URL'], namespace: ENV['REDIS_NAMESPACE']) }
      else
        proc { Redis.new(url: ENV['REDIS_URL']) }
      end
    end

    def self.redis
      @redis ||= connection.call
    end
  end
end

# Set Redis connections for both Sidekiq server and client
Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(&WebTaskRunner::RedisModule.connection)
end

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(&WebTaskRunner::RedisModule.connection)
end
