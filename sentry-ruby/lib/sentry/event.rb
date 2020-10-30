# frozen_string_literal: true

require 'socket'
require 'securerandom'
require 'sentry/event/options'
require 'sentry/interface'
require 'sentry/backtrace'
require 'sentry/utils/deep_merge'
require 'sentry/utils/real_ip'

module Sentry
  class Event
    ATTRIBUTES = %i(
      event_id level timestamp
      release environment server_name modules
      message user tags contexts extra
      fingerprint breadcrumbs backtrace transaction
      platform sdk
    )

    attr_accessor(*ATTRIBUTES)
    attr_reader :id, :configuration

    alias event_id id

    def initialize(options:, configuration:)
      # this needs to go first because some setters rely on configuration
      @configuration = configuration

      # Set some simple default values
      @id            = SecureRandom.uuid.delete("-")
      @timestamp     = Time.now.utc
      @platform      = :ruby
      @sdk           = Sentry.sdk_meta

      # Set some attributes with empty hashes to allow merging
      @interfaces        = {}

      @user          = options.user
      @extra         = options.extra
      @contexts      = options.contexts
      @tags          = configuration.tags.merge(options.tags)

      @fingerprint = options.fingerprint

      @server_name = options.server_name || configuration.server_name
      @environment = options.environment || configuration.current_environment
      @release = options.release || configuration.release
      @modules = list_gem_specs if configuration.send_modules

      @message = options.message if options.message

      self.level = options.level

      # Allow attributes to be set on the event at initialization
      yield self if block_given?

      if !options.backtrace.empty?
        interface(:stacktrace) do |int|
          int.frames = stacktrace_interface_from(options.backtrace)
        end
      end
    end

    class << self
      def get_log_message(event_hash)
        message = event_hash[:message] || event_hash['message']
        message = get_message_from_exception(event_hash) if message.empty?
        message = '<no message value>' if message.empty?
        message
      end

      def get_message_from_exception(event_hash)
        (
          event_hash &&
          event_hash[:exception] &&
          event_hash[:exception][:values] &&
          event_hash[:exception][:values][0] &&
          "#{event_hash[:exception][:values][0][:type]}: #{event_hash[:exception][:values][0][:value]}"
        )
      end
    end

    def timestamp=(time)
      @timestamp = time.is_a?(Time) ? time.strftime('%Y-%m-%dT%H:%M:%S') : time
    end

    def level=(new_level) # needed to meet the Sentry spec
      @level = new_level.to_s == "warn" ? :warning : new_level
    end

    def rack_env=(env)
      unless interface(:http) || env.empty?
        interface :http do |int|
          int.from_rack(env)
        end

        if configuration.send_default_pii && ip = calculate_real_ip_from_rack(env.dup)
          user[:ip_address] = ip
        end
      end
    end

    def interface(name, value = nil, &block)
      int = Interface.registered[name]
      raise(Error, "Unknown interface: #{name}") unless int

      @interfaces[int.sentry_alias] = int.new(value, &block) if value || block
      @interfaces[int.sentry_alias]
    end

    def to_hash
      data = ATTRIBUTES.each_with_object({}) do |att, memo|
        memo[att] = public_send(att) if public_send(att)
      end

      data[:breadcrumbs] = breadcrumbs.to_hash if breadcrumbs

      @interfaces.each_pair do |name, int_data|
        data[name.to_sym] = int_data.to_hash
      end
      data
    end

    def to_json_compatible
      JSON.parse(JSON.generate(to_hash))
    end

    def add_exception_interface(exc)
      interface(:exception) do |exc_int|
        exceptions = Sentry::Utils::ExceptionCauseChain.exception_to_array(exc).reverse
        backtraces = Set.new
        exc_int.values = exceptions.map do |e|
          SingleExceptionInterface.new do |int|
            int.type = e.class.to_s
            int.value = e.to_s
            int.module = e.class.to_s.split('::')[0...-1].join('::')

            int.stacktrace =
              if e.backtrace && !backtraces.include?(e.backtrace.object_id)
                backtraces << e.backtrace.object_id
                StacktraceInterface.new do |stacktrace|
                  stacktrace.frames = stacktrace_interface_from(e.backtrace)
                end
              end
          end
        end
      end
    end

    def stacktrace_interface_from(backtrace)
      project_root = configuration.project_root.to_s

      Backtrace.parse(backtrace, configuration: configuration).lines.reverse.each_with_object([]) do |line, memo|
        frame = StacktraceInterface::Frame.new(project_root)
        frame.abs_path = line.file if line.file
        frame.function = line.method if line.method
        frame.lineno = line.number
        frame.in_app = line.in_app
        frame.module = line.module_name if line.module_name

        if configuration[:context_lines] && frame.abs_path
          frame.pre_context, frame.context_line, frame.post_context = \
            configuration.linecache.get_file_context(frame.abs_path, frame.lineno, configuration[:context_lines])
        end

        memo << frame if frame.filename
      end
    end

    private

    # When behind a proxy (or if the user is using a proxy), we can't use
    # REMOTE_ADDR to determine the Event IP, and must use other headers instead.
    def calculate_real_ip_from_rack(env)
      Utils::RealIp.new(
        :remote_addr => env["REMOTE_ADDR"],
        :client_ip => env["HTTP_CLIENT_IP"],
        :real_ip => env["HTTP_X_REAL_IP"],
        :forwarded_for => env["HTTP_X_FORWARDED_FOR"]
      ).calculate_ip
    end

    def list_gem_specs
      # Older versions of Rubygems don't support iterating over all specs
      Hash[Gem::Specification.map { |spec| [spec.name, spec.version.to_s] }] if Gem::Specification.respond_to?(:map)
    end
  end
end
