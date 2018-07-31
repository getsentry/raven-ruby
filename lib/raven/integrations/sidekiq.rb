require 'time'
require 'sidekiq'
require 'raven/integrations/sidekiq/sidekiq_cleanup_middleware'
require 'raven/integrations/sidekiq/sidekiq_error_handler'

if Sidekiq::VERSION > '3'
  Sidekiq.configure_server do |config|
    config.error_handlers << Raven::SidekiqErrorHandler.new
    config.server_middleware do |chain|
      chain.add Raven::SidekiqCleanupMiddleware
    end
  end
end
