require "rails"
require "sentry/rails/capture_exception"
require "sentry/rails/backtrace_cleaner"
require "sentry/rails/controller_methods"
require "sentry/rails/controller_transaction"
require "sentry/rails/active_job"
require "sentry/rails/overrides/streaming_reporter"

module Sentry
  class Railtie < ::Rails::Railtie
    initializer "sentry.use_rack_middleware" do |app|
      app.config.middleware.insert 0, Sentry::Rails::CaptureException
    end

    initializer 'sentry.action_controller' do
      ActiveSupport.on_load :action_controller do
        include Sentry::Rails::ControllerMethods
        include Sentry::Rails::ControllerTransaction
        ActionController::Live.send(:prepend, Sentry::Rails::Overrides::StreamingReporter)
      end
    end

    initializer 'sentry.action_view' do
      ActiveSupport.on_load :action_view do
        ActionView::StreamingTemplateRenderer::Body.send(:prepend, Sentry::Rails::Overrides::StreamingReporter)
      end
    end

    config.after_initialize do
      Sentry.configuration.logger = ::Rails.logger

      backtrace_cleaner = Sentry::Rails::BacktraceCleaner.new

      Sentry.configuration.backtrace_cleanup_callback = lambda do |backtrace|
        backtrace_cleaner.clean(backtrace)
      end
    end

    # config.after_initialize do
    #   if Sentry.configuration.breadcrumbs_logger.include?(:active_support_logger) ||
    #      Sentry.configuration.rails_activesupport_breadcrumbs

    #     require 'sentry/breadcrumbs/active_support_logger'
    #     Sentry::Breadcrumbs::ActiveSupportLogger.inject
    #   end

    #   if Sentry.configuration.rails_report_rescued_exceptions
    #     require 'sentry/integrations/rails/overrides/debug_exceptions_catcher'
    #     if defined?(::ActionDispatch::DebugExceptions)
    #       exceptions_class = ::ActionDispatch::DebugExceptions
    #     elsif defined?(::ActionDispatch::ShowExceptions)
    #       exceptions_class = ::ActionDispatch::ShowExceptions
    #     end

    #     Sentry.safely_prepend(
    #       "DebugExceptionsCatcher",
    #       :from => Sentry::Rails::Overrides,
    #       :to => exceptions_class
    #     )
    #   end
    # end

    initializer 'sentry.active_job' do
      ActiveSupport.on_load :active_job do
        require 'sentry/rails/active_job'
      end
    end

    # rake_tasks do
    #   require 'sentry/integrations/tasks'
    # end
  end
end
