require 'spec_helper'

describe Raven do
  let(:event) { Raven::Event.new(:id => "event_id") }
  let(:options) { double("options") }

  before do
    allow(Raven.instance).to receive(:send_event)
    allow(Raven::Event).to receive(:from_message) { event }
    allow(Raven::Event).to receive(:from_exception) { event }
  end

  describe '.capture_message' do
    let(:message) { "Test message" }

    it 'sends the result of Event.capture_message' do
      expect(Raven::Event).to receive(:from_message).with(message, options)
      expect(Raven.instance).to receive(:send_event).with(event)

      Raven.capture_message(message, options)
    end

    it 'yields the event to a passed block' do
      expect { |b| Raven.capture_message(message, options, &b) }.to yield_with_args(event)
    end
  end

  describe '.capture_message when async' do
    let(:message) { "Test message" }

    around do |example|
      prior_async = Raven.configuration.async
      Raven.configuration.async = proc { :ok }
      example.run
      Raven.configuration.async = prior_async
    end

    it 'sends the result of Event.capture_message' do
      expect(Raven::Event).to receive(:from_message).with(message, options)
      expect(Raven).not_to receive(:send_event).with(event)

      expect(Raven.configuration.async).to receive(:call).with(event.to_json_compatible)
      Raven.capture_message(message, options)
    end

    it 'returns the generated event' do
      returned = Raven.capture_message(message, options)
      expect(returned).to eq(event)
    end
  end

  describe '.capture_exception' do
    let(:exception) { build_exception }

    it 'sends the result of Event.capture_exception' do
      expect(Raven::Event).to receive(:from_exception).with(exception, options)
      expect(Raven.instance).to receive(:send_event).with(event)

      Raven.capture_exception(exception, options)
    end

    it 'yields the event to a passed block' do
      expect { |b| Raven.capture_exception(exception, options, &b) }.to yield_with_args(event)
    end
  end

  describe '.capture_exception when async' do
    let(:exception) { build_exception }

    around do |example|
      prior_async = Raven.configuration.async
      Raven.configuration.async = proc { :ok }
      example.run
      Raven.configuration.async = prior_async
    end

    it 'sends the result of Event.capture_exception' do
      expect(Raven::Event).to receive(:from_exception).with(exception, options)
      expect(Raven).not_to receive(:send_event).with(event)

      expect(Raven.configuration.async).to receive(:call).with(event.to_json_compatible)
      Raven.capture_exception(exception, options)
    end

    it 'returns the generated event' do
      returned = Raven.capture_exception(exception, options)
      expect(returned).to eq(event)
    end
  end

  describe '.capture_exception with a should_capture callback' do
    let(:exception) { build_exception }

    it 'sends the result of Event.capture_exception according to the result of should_capture' do
      expect(Raven).not_to receive(:send_event).with(event)

      prior_should_capture = Raven.configuration.should_capture
      Raven.configuration.should_capture = proc { false }
      expect(Raven.configuration.should_capture).to receive(:call).with(exception)
      expect(Raven.capture_exception(exception, options)).to be false
      Raven.configuration.should_capture = prior_should_capture
    end
  end

  describe '.capture' do
    context 'given a block' do
      it 'yields to the given block' do
        expect { |b| described_class.capture(&b) }.to yield_with_no_args
      end
    end

    context 'not given a block' do
      let(:options) { { :key => 'value' } }

      def capture_in_separate_process
        pipe_in, pipe_out = IO.pipe

        fork do
          pipe_in.close
          described_class.capture(options)

          allow(Raven.instance).to receive(:capture_type) do |exception, _options|
            pipe_out.puts exception.message
          end

          # silence process
          $stderr.reopen('/dev/null', 'w')
          $stdout.reopen('/dev/null', 'w')

          yield
          exit
        end

        pipe_out.close
        captured_messages = pipe_in.read
        pipe_in.close
        # sometimes the at_exit hook was registered multiple times
        captured_messages.split("\n").last
      end

      it 'does not yield' do
        # As there is no yield matcher that does not require a probe (e.g. this
        # is not valid: expect { |b| described_class.capture }.to_not yield_control),
        # expect that a LocalJumpError, which is raised when yielding when no
        # block is defined, is not raised.
        described_class.capture
      end

      it 'installs an at exit hook that will capture exceptions' do
        skip('fork not supported in jruby') if RUBY_PLATFORM == 'java'
        captured_message = capture_in_separate_process { raise 'test error' }
        expect(captured_message).to eq('test error')
      end
    end
  end

  describe '.annotate_exception' do
    let(:exception) { build_exception }

    def ivars(object)
      object.instance_variables.map(&:to_s)
    end

    it 'adds an annotation to the exception' do
      expect(ivars(exception)).not_to include("@__raven_context")
      Raven.annotate_exception(exception, {})
      expect(ivars(exception)).to include("@__raven_context")
      expect(exception.instance_variable_get(:@__raven_context)).to \
        be_kind_of Hash
    end
  end

  describe '.report_status' do
    context 'when configured' do
      let(:message) do
        "Raven #{Raven::VERSION} ready to catch errors"
      end

      it 'logs a ready message' do
        Raven.configuration.silence_ready = false
        expect(Raven.logger).to receive(:info).with(message)
        Raven.report_status
      end
    end

    context 'when "silence_ready" configuration is true' do
      it 'logs nothing' do
        Raven.configuration.silence_ready = true
        expect(Raven.logger).not_to receive(:info)
        Raven.report_status
      end
    end

    context 'when no server configured' do
      let(:not_ready_message) do
        "Raven #{Raven::VERSION} configured not to capture errors (no server configured)."
      end

      it 'logs not ready message' do
        Raven.configuration.silence_ready = false
        Raven.configuration.server = ''

        expect(Raven.logger).to receive(:info).with(not_ready_message)
        Raven.report_status
      end
    end

    context 'when current environment not configured' do
      let(:not_ready_message) do
        "Raven #{Raven::VERSION} configured not to capture errors (current environment not listed)."
      end

      it 'logs not ready message' do
        Raven.configuration.silence_ready = false
        Raven.configuration.server = "dummy://woopwoop"
        Raven.configuration.current_environment = 'test'
        Raven.configuration.environments = %w(not_test)

        expect(Raven.logger).to receive(:info).with(not_ready_message)
        Raven.report_status
      end
    end

    context 'when neither a server nor the current environment are configured' do
      let(:not_ready_message) do
        "Raven #{Raven::VERSION} configured not to capture errors (no server configured, current environment not listed)."
      end

      it 'logs not ready message' do
        Raven.configuration.silence_ready = false
        Raven.configuration.server = ''
        Raven.configuration.current_environment = 'test'
        Raven.configuration.environments = %w(not_test)

        expect(Raven.logger).to receive(:info).with(not_ready_message)
        Raven.report_status
      end
    end
  end

  describe '.inject_only' do
    before do
      allow(Gem.loaded_specs).to receive(:keys).and_return(%w(railties rack sidekiq))
    end

    it 'loads integrations when they are valid configurations' do
      expect(Raven).to receive(:load_integration).once.with('railties')
      expect(Raven).to receive(:load_integration).once.with('sidekiq')

      Raven.inject_only(:railties, :sidekiq)
    end

    it 'skips any integrations that are not supported' do
      expect(Raven).to receive(:load_integration).once.with('railties')
      expect(Raven.logger).to receive(:warn).with('Integrations do not exist: doesnot, exist')

      Raven.inject_only(:railties, :doesnot, :exist)
    end

    it 'skips any integrations that are not loaded in the gemspec' do
      expect(Raven).to receive(:load_integration).once.with('railties')

      Raven.inject_only(:railties, :delayed_job)
    end
  end

  describe '.inject_without' do
    before do
      allow(Gem.loaded_specs).to receive(:keys).and_return(Raven::AVAILABLE_INTEGRATIONS)
    end

    it 'injects all integrations except those passed as an argument' do
      expect(Raven).to receive(:load_integration).once.with('rake')

      Raven.inject_without(:delayed_job, :logger, :railties, :sidekiq, :rack, :"rack-timeout")
    end
  end

  describe '.last_event_id' do
    let(:message) { "Test message" }

    it 'sends the result of Event.capture_message' do
      expect(Raven.instance).to receive(:send_event).with(event)

      Raven.capture_message("Test message", options)

      expect(Raven.last_event_id).to eq(event.id)
    end

    it 'yields the event to a passed block' do
      expect { |b| Raven.capture_message(message, options, &b) }.to yield_with_args(event)
    end
  end
end
