require 'rubygems'
require 'socket'
require 'uuidtools'

require 'raven/error'
require 'raven/linecache'

module Raven

  class Event

    LOG_LEVELS = {
      "debug" => 10,
      "info" => 20,
      "warn" => 30,
      "warning" => 30,
      "error" => 40,
      "fatal" => 50,
    }

    BACKTRACE_RE = /^(.+?):(\d+)(?::in `(.+?)')?$/

    attr_reader :id
    attr_accessor :project, :message, :timestamp, :level
    attr_accessor :logger, :culprit, :server_name, :modules, :extra, :tags

    def initialize(options={}, &block)
      @configuration = options[:configuration] || Raven.configuration
      @interfaces = {}

      @id = options[:id] || UUIDTools::UUID.random_create.hexdigest
      @message = options[:message]
      @timestamp = options[:timestamp] || Time.now.utc
      @level = options[:level] || :error
      @logger = options[:logger] || 'root'
      @culprit = options[:culprit]
      @extra = options[:extra]
      @tags = options[:tags]

      # Try to resolve the hostname to an FQDN, but fall back to whatever the load name is
      hostname = Socket.gethostname
      hostname = Socket.gethostbyname(hostname).first rescue hostname
      @server_name = options[:server_name] || hostname

      # Older versions of Rubygems don't support iterating over all specs
      if @configuration.send_modules && Gem::Specification.respond_to?(:map)
        options[:modules] ||= Hash[Gem::Specification.map {|spec| [spec.name, spec.version.to_s]}]
      end
      @modules = options[:modules]

      block.call(self) if block

      # Some type coercion
      @timestamp = @timestamp.strftime('%Y-%m-%dT%H:%M:%S') if @timestamp.is_a?(Time)
      @level = LOG_LEVELS[@level.to_s.downcase] if @level.is_a?(String) || @level.is_a?(Symbol)

      # Basic sanity checking
      raise Error.new('A message is required for all events') unless @message && !@message.empty?
      raise Error.new('A timestamp is required for all events') unless @timestamp
    end

    def interface(name, value=nil, &block)
      int = Raven::find_interface(name)
      raise Error.new("Unknown interface: #{name}") unless int
      @interfaces[int.name] = int.new(value, &block) if value || block
      @interfaces[int.name]
    end

    def [](key)
      interface(key)
    end

    def []=(key, value)
      interface(key, value)
    end

    def to_hash
      data = {
        'event_id' => self.id,
        'message' => self.message,
        'timestamp' => self.timestamp,
        'level' => self.level,
        'project' => self.project,
        'logger' => self.logger,
      }
      data['culprit'] = self.culprit if self.culprit
      data['server_name'] = self.server_name if self.server_name
      data['modules'] = self.modules if self.modules
      data['extra'] = self.extra if self.extra
      data['tags'] = self.tags if self.tags
      @interfaces.each_pair do |name, int_data|
        data[name] = int_data.to_hash
      end
      data
    end

    def self.capture_exception(exc, options={}, &block)
      configuration = options[:configuration] || Raven.configuration
      if exc.is_a?(Raven::Error)
        # Try to prevent error reporting loops
        Raven.logger.info "Refusing to capture Raven error: #{exc.inspect}"
        return nil
      end
      if configuration[:excluded_exceptions].include? exc.class.name
        Raven.logger.info "User excluded error: #{exc.inspect}"
        return nil
      end

      context_lines = configuration[:context_lines]

      new(options) do |evt|
        evt.message = "#{exc.class.to_s}: #{exc.message}"
        evt.level = options[:level] || :error
        evt.parse_exception(exc)
        if (exc.backtrace)
          evt.interface :stack_trace do |int|
            backtrace = Backtrace.parse(exc.backtrace)
            int.frames = backtrace.lines.reverse.map do |line|
              int.frame do |frame|
                frame.abs_path = line.file
                frame.function = line.method
                frame.lineno = line.number
                frame.in_app = line.in_app
                if context_lines
                  frame.pre_context, frame.context_line, frame.post_context = \
                    evt.get_context(frame.abs_path, frame.lineno, context_lines)
                end
              end
            end
            evt.culprit = evt.get_culprit(int.frames)
          end
        end
        block.call(evt) if block
      end
    end

    def self.capture_rack_exception(exc, rack_env, options={}, &block)
      capture_exception(exc, options) do |evt|
        evt.interface :http do |int|
          int.from_rack(rack_env)
        end
        block.call(evt) if block
      end
    end

    def self.capture_message(message, options={})
      new(options) do |evt|
        evt.message = message
        evt.level = options[:level] || :error
        evt.interface :message do |int|
          int.message = message
        end
      end
    end

    # Because linecache can go to hell
    def self._source_lines(path, from, to)
    end

    def get_context(filename, lineno, context)
      lines = (2 * context + 1).times.map do |i|
        Raven::LineCache::getline(filename, lineno - context + i)
      end
      [lines[0..(context-1)], lines[context], lines[(context+1)..-1]]
    end

    def get_culprit(frames)
      lastframe = frames[-1]
      "#{lastframe.filename} in #{lastframe.function}" if lastframe
    end

    def parse_exception(exception)
      interface(:exception) do |int|
        int.type = exception.class.to_s
        int.value = exception.message
        int.module = exception.class.to_s.split('::')[0...-1].join('::')
      end
    end

    # For cross-language compat
    class << self
      alias :captureException :capture_exception
      alias :captureMessage :capture_message
    end

    private
  end
end
