require 'spec_helper'
require 'raven/instance'

describe Raven::Instance do
  let(:event) { Raven::Event.new(:id => "event_id") }
  let(:options) { { :key => "value" } }
  let(:context) { nil }

  subject { described_class.new(context) }

  before do
    allow(subject).to receive(:send_event)
    allow(Raven::Event).to receive(:from_message) { event }
    allow(Raven::Event).to receive(:from_exception) { event }

    subject.configuration.dsn = "dummy://woopwoop"
  end

  describe '#context' do
    it 'is Raven.context by default' do
      expect(subject.context).to equal(Raven.context)
    end

    context 'initialized with a context' do
      let(:context) { :explicit }

      it 'is not Raven.context' do
        expect(subject.context).to_not equal(Raven.context)
      end
    end
  end

  describe '#capture_type' do
    describe 'as #capture_message' do
      let(:message) { "Test message" }

      it 'sends the result of Event.capture_message' do
        expect(Raven::Event).to receive(:from_message).with(message,
                                                            :context => subject.context,
                                                            :configuration => subject.configuration,
                                                            :key => "value")
        expect(subject).to receive(:send_event).with(event)

        subject.capture_type(message, options)
      end

      it 'has an alias' do
        expect(Raven::Event).to receive(:from_message).with(message,
                                                            :context => subject.context,
                                                            :configuration => subject.configuration,
                                                            :key => "value")
        expect(subject).to receive(:send_event).with(event)

        subject.capture_message(message, options)
      end

      it 'yields the event to a passed block' do
        expect { |b| subject.capture_type(message, options, &b) }.to yield_with_args(event)
      end
    end

    describe 'as #capture_message when async' do
      let(:message) { "Test message" }

      around do |example|
        prior_async = subject.configuration.async
        subject.configuration.async = proc { :ok }
        example.run
        subject.configuration.async = prior_async
      end

      it 'sends the result of Event.capture_type' do
        expect(Raven::Event).to receive(:from_message).with(message,
                                                            :context => subject.context,
                                                            :configuration => subject.configuration,
                                                            :key => "value")
        expect(subject).not_to receive(:send_event).with(event)

        expect(subject.configuration.async).to receive(:call).with(event.to_json_compatible)
        subject.capture_type(message, options)
      end

      it 'returns the generated event' do
        returned = subject.capture_type(message, options)
        expect(returned).to eq(event)
      end
    end

    describe 'as #capture_exception' do
      let(:exception) { build_exception }

      it 'sends the result of Event.capture_exception' do
        expect(Raven::Event).to receive(:from_exception).with(exception,
                                                              :context => subject.context,
                                                              :configuration => subject.configuration,
                                                              :key => "value")
        expect(subject).to receive(:send_event).with(event)

        subject.capture_type(exception, options)
      end

      it 'has an alias' do
        expect(Raven::Event).to receive(:from_exception).with(exception,
                                                              :context => subject.context,
                                                              :configuration => subject.configuration,
                                                              :key => "value")
        expect(subject).to receive(:send_event).with(event)

        subject.capture_exception(exception, options)
      end

      it 'yields the event to a passed block' do
        expect { |b| subject.capture_type(exception, options, &b) }.to yield_with_args(event)
      end
    end

    describe 'as #capture_exception when async' do
      let(:exception) { build_exception }

      context "when correctly configured" do
        around do |example|
          prior_async = subject.configuration.async
          subject.configuration.async = proc { :ok }
          example.run
          subject.configuration.async = prior_async
        end

        it 'sends the result of Event.capture_exception' do
          expect(Raven::Event).to receive(:from_exception).with(exception,
                                                                :context => subject.context,
                                                                :configuration => subject.configuration,
                                                                :key => "value")
          expect(subject).not_to receive(:send_event).with(event)

          expect(subject.configuration.async).to receive(:call).with(event.to_json_compatible)
          subject.capture_type(exception, options)
        end

        it 'returns the generated event' do
          returned = subject.capture_type(exception, options)
          expect(returned).to eq(event)
        end
      end

      context "when async raises an exception" do
        around do |example|
          prior_async = subject.configuration.async
          subject.configuration.async = proc { raise TypeError }
          example.run
          subject.configuration.async = prior_async
        end

        it 'sends the result of Event.capture_exception via fallback' do
          expect(Raven::Event).to receive(:from_exception).with(exception,
                                                                :context => subject.context,
                                                                :configuration => subject.configuration,
                                                                :key => "value")

          expect(subject.configuration.async).to receive(:call).with(event.to_json_compatible)
          subject.capture_type(exception, options)
        end
      end
    end

    describe 'as #capture_exception with a should_capture callback' do
      let(:exception) { build_exception }

      it 'sends the result of Event.capture_exception according to the result of should_capture' do
        expect(subject).not_to receive(:send_event).with(event)

        subject.configuration.should_capture = proc { false }
        expect(subject.configuration.should_capture).to receive(:call).with(exception)
        expect(subject.capture_type(exception, options)).to be false
      end
    end
  end

  describe '#capture' do
    context 'given a block' do
      it 'yields to the given block' do
        expect { |b| subject.capture(&b) }.to yield_with_no_args
      end
    end

    it 'does not install an at_exit hook' do
      expect(Kernel).not_to receive(:at_exit)
      subject.capture {}
    end
  end

  describe '#annotate_exception' do
    let(:exception) { build_exception }

    def ivars(object)
      object.instance_variables.map(&:to_s)
    end

    it 'adds an annotation to the exception' do
      expect(ivars(exception)).not_to include("@__raven_context")
      subject.annotate_exception(exception, {})
      expect(ivars(exception)).to include("@__raven_context")
      expect(exception.instance_variable_get(:@__raven_context)).to \
        be_kind_of Hash
    end
  end

  describe '#report_status' do
    let(:ready_message) do
      "Raven #{Raven::VERSION} ready to catch errors"
    end

    let(:not_ready_message) do
      "Raven #{Raven::VERSION} configured not to capture errors."
    end

    it 'logs a ready message when configured' do
      subject.configuration.silence_ready = false
      expect(subject.configuration).to(
        receive(:capture_allowed?).and_return(true)
      )
      expect(subject.logger).to receive(:info).with(ready_message)
      subject.report_status
    end

    it 'logs not ready message if the config does not send in current environment' do
      subject.configuration.silence_ready = false
      expect(subject.configuration).to(
        receive(:capture_allowed?).and_return(false)
      )
      expect(subject.logger).to receive(:info).with(not_ready_message)
      subject.report_status
    end

    it 'logs nothing if "silence_ready" configuration is true' do
      subject.configuration.silence_ready = true
      expect(subject.logger).not_to receive(:info)
      subject.report_status
    end
  end

  describe '.last_event_id' do
    let(:message) { "Test message" }

    it 'sends the result of Event.capture_type' do
      expect(subject).to receive(:send_event).with(event)

      subject.capture_type("Test message", options)

      expect(subject.last_event_id).to eq(event.id)
    end

    it 'yields the event to a passed block' do
      expect { |b| subject.capture_type(message, options, &b) }.to yield_with_args(event)
    end
  end
end
