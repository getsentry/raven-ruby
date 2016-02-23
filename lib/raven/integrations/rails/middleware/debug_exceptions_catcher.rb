module Raven
  class Rails
    module Middleware
      module DebugExceptionsCatcher
        def render_exception(env_or_request, exception)
          begin
            env = env_or_request.respond_to?(:env) ? env_or_request.env : env_or_request
            Raven::Rack.capture_exception(exception, env) if Raven.configuration.catch_debugged_exceptions
          rescue # rubocop:disable Lint/HandleExceptions
          end
          super
        end
      end

      module OldDebugExceptionsCatcher
        def self.included(base)
          base.send(:alias_method_chain, :render_exception, :raven)
        end

        def render_exception_with_raven(env_or_request, exception)
          begin
            env = env_or_request.respond_to?(:env) ? env_or_request.env : env_or_request
            Raven::Rack.capture_exception(exception, env) if Raven.configuration.catch_debugged_exceptions
          rescue # rubocop:disable Lint/HandleExceptions
          end
          render_exception_without_raven(env_or_request, exception)
        end
      end
    end
  end
end
