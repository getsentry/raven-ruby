require "json"
require "base64"
require "sentry/transports/state"

module Sentry
  module Transports
    class Transport
      PROTOCOL_VERSION = '5'
      USER_AGENT = "sentry-ruby/#{Sentry::VERSION}"
      CONTENT_TYPE = 'application/json'

      attr_accessor :configuration, :state

      def initialize(configuration)
        @configuration = configuration
        @state = State.new
      end

      def send_data(data, options = {})
        raise NotImplementedError
      end

      def send_event(event)
        content_type, encoded_data = prepare_encoded_event(event)

        begin
          if configuration.async?
            begin
              # We have to convert to a JSON-like hash, because background job
              # processors (esp ActiveJob) may not like weird types in the event hash
              configuration.async.call(event.to_json_compatible)
            rescue => e
              configuration.logger.error("async event sending failed: #{e.message}")
              send_data(encoded_data, content_type: content_type)
            end
          else
            send_data(encoded_data, content_type: content_type)
          end

          successful_send
        rescue => e
          failed_send(e, event)
          return
        end

        event
      end

      def generate_auth_header
        now = Time.now.to_i.to_s
        fields = {
          'sentry_version' => PROTOCOL_VERSION,
          'sentry_client' => USER_AGENT,
          'sentry_timestamp' => now,
          'sentry_key' => configuration.public_key
        }
        fields['sentry_secret'] = configuration.secret_key unless configuration.secret_key.nil?
        'Sentry ' + fields.map { |key, value| "#{key}=#{value}" }.join(', ')
      end

      private

      def prepare_encoded_event(event)
        # Convert to hash
        event_hash = event.to_hash

        unless @state.should_try?
          failed_send(nil, event_hash)
          return
        end

        event_id = event_hash[:event_id] || event_hash['event_id']
        configuration.logger.info "Sending event #{event_id} to Sentry"
        encode(event_hash)
      end

      def successful_send
        @state.success
      end

      def encode(event)
        encoded = JSON.fast_generate(event.to_hash)

        case configuration.encoding
        when 'gzip'
          ['application/octet-stream', Base64.strict_encode64(Zlib::Deflate.deflate(encoded))]
        else
          ['application/json', encoded]
        end
      end

      def failed_send(e, event)
        if e # exception was raised
          @state.failure
          configuration.logger.warn "Unable to record event with remote Sentry server (#{e.class} - #{e.message}):\n#{e.backtrace[0..10].join("\n")}"
        else
          configuration.logger.warn "Not sending event due to previous failure(s)."
        end
        configuration.logger.warn("Failed to submit event: #{Event.get_log_message(event.to_hash)}")
      end
    end
  end
end

require "sentry/transports/dummy"
require "sentry/transports/http"
require "sentry/transports/stdout"
