# frozen_string_literal: true
require 'securerandom'

module Raven
  class Event
    # See Sentry server default limits at
    # https://github.com/getsentry/sentry/blob/master/src/sentry/conf/server.py
    MAX_MESSAGE_SIZE_IN_BYTES = 1024 * 8
    TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'.freeze
    SDK = { "name" => "raven-ruby", "version" => Raven::VERSION }.freeze

    attr_accessor :event_id, :logger, :transaction, :server_name, :release, :modules,
                  :checksum, :fingerprint, :environment,
                  :backtrace, :platform, :sdk, :instance, :request, :exception,
                  :stacktrace, :context
    attr_reader   :level, :timestamp, :time_spent, :logentry

    extend Forwardable
    def_delegators :instance, :configuration, :breadcrumbs
    def_delegators :context, :tags, :user, :extra, :tags=, :user=, :extra=

    def initialize(init = {})
      self.instance      = Raven.instance
      self.event_id      = SecureRandom.uuid.delete!("-")
      self.timestamp     = Time.now.utc
      self.level         = :error
      self.logger        = :ruby
      self.platform      = :ruby
      self.sdk           = SDK

      self.context = Context.new

      init.each_pair { |key, val| public_send("#{key}=", val) }
      yield self if block_given?

      set_core_attributes_from_configuration
      set_core_attributes_from_context
    end

    def self.from_exception(exc, options = {})
      options = Raven::Utils::DeepMergeHash.deep_merge(exception_context(exc), options)

      new(options) do |evt|
        evt.message = "#{exc.class}: #{exc.message}"
        yield evt if block_given?
        evt.exception = ExceptionInterface.from_exception(exc, evt.configuration)
      end
    end

    def self.exception_context(exc)
      exc.respond_to?(:raven_context) ? exc.raven_context : {}
    end

    def self.from_message(message, options = {})
      new(options) do |evt|
        evt.message = message, options[:message_params] || []

        yield evt if block_given?

        evt.stacktrace = StacktraceInterface.new do |int|
          int.frames = StacktraceInterface::Frame.from_backtrace(options[:backtrace], evt.configuration)
        end if options[:backtrace]
      end
    end

    def message
      logentry && logentry.unformatted_message
    end

    def message=(args)
      message, params = *args
      @logentry = MessageInterface.new
      @logentry.message = message.byteslice(0...MAX_MESSAGE_SIZE_IN_BYTES) # Messages limited to 10kb
      @logentry.params = params
    end

    def timestamp=(time)
      @timestamp = time.is_a?(Time) ? time.utc.strftime(TIME_FORMAT) : time
    end

    def time_spent=(time)
      @time_spent = time.is_a?(Float) ? (time * 1000).to_i : time
    end

    def level=(new_level) # needed to meet the Sentry spec
      new_level = new_level.downcase.to_sym
      @level = (new_level == :warn) ? :warning : new_level
    end

    def to_hash
      data = [:checksum, :environment, :event_id, :fingerprint, :level,
              :logger, :message, :modules, :platform, :release, :sdk, :server_name,
              :time_spent, :timestamp].each_with_object({}) do |att, memo|
        val = public_send(att)
        memo[att] = val unless val.nil?
      end

      collector = ContextCollector.new(context, instance.context, configuration.context)
      [:user, :tags, :extra, :transaction].each do |ctx|
        val = collector.public_send(ctx)
        data[ctx] = val
      end

      [:logentry, :breadcrumbs, :exception, :stacktrace, :request].each do |int|
        val = public_send(int)
        data[int] = val.to_hash if val
      end

      data
    end

    def to_json_compatible
      cleaned_hash = async_json_processors.reduce(to_hash) { |a, e| e.process(a) }
      JSON.parse(JSON.generate(cleaned_hash))
    end

    private

    def set_core_attributes_from_configuration
      self.server_name ||= configuration.server_name
      self.release     ||= configuration.release
      self.modules     ||= configuration.modules
      self.environment ||= configuration.current_environment
    end

    def set_core_attributes_from_context
      # If this is a Rack event, merge Rack context
      add_rack_context if !request && !instance.context.rack.empty?
    end

    def add_rack_context
      self.request = HttpInterface.new.from_rack(instance.context.rack)

      # When behind a proxy (or if the user is using a proxy), we can't use
      # REMOTE_ADDR to determine the Event IP, and must use other headers instead.
      user[:ip_address] = Utils::RealIp.new(instance.context.rack).calculate_ip
    end

    def async_json_processors
      [Raven::Processor::RemoveCircularReferences, Raven::Processor::UTF8Conversion].map { |v| v.new(nil) }
    end
  end
end
