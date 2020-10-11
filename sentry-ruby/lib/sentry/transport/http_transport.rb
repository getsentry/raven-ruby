require 'faraday'

module Sentry
  class HTTPTransport < Transport
    attr_accessor :conn, :adapter

    def initialize(*args)
      super
      self.adapter = @transport_configuration.http_adapter || Faraday.default_adapter
      self.conn = set_conn
    end

    def send_data(data, options = {})
      unless configuration.sending_allowed?
        logger.debug("Event not sent: #{configuration.error_messages}")
      end

      project_id = @dsn.project_id
      path = @dsn.path + "/"

      conn.post "#{path}api/#{project_id}/store/" do |req|
        req.headers['Content-Type'] = options[:content_type]
        req.headers['X-Sentry-Auth'] = generate_auth_header
        req.body = data
      end
    rescue Faraday::Error => e
      error_info = e.message
      if e.response && e.response[:headers]['x-sentry-error']
        error_info += " Error in headers is: #{e.response[:headers]['x-sentry-error']}"
      end
      raise Sentry::Error, error_info
    end

    private

    def set_conn
      server = @dsn.server

      configuration.logger.debug "Sentry HTTP Transport connecting to #{server}"

      Faraday.new(server, :ssl => ssl_configuration, :proxy => @transport_configuration.proxy) do |builder|
        @transport_configuration.faraday_builder&.call(builder)
        builder.response :raise_error
        builder.options.merge! faraday_opts
        builder.headers[:user_agent] = "sentry-ruby/#{Sentry::VERSION}"
        builder.adapter(*adapter)
      end
    end

    # TODO: deprecate and replace where possible w/Faraday Builder
    def faraday_opts
      [:timeout, :open_timeout].each_with_object({}) do |opt, memo|
        memo[opt] = @transport_configuration.public_send(opt) if @transport_configuration.public_send(opt)
      end
    end

    def ssl_configuration
      (@transport_configuration.ssl || {}).merge(
        :verify => @transport_configuration.ssl_verification,
        :ca_file => @transport_configuration.ssl_ca_file
      )
    end
  end
end
