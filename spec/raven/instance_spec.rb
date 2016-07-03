require 'spec_helper'
require 'raven/instance'

describe Raven::Instance do
  let(:event) { double("event", :id => "event_id") }
  let(:options) { double("options") }

  subject { described_class.new }

  before do
    allow(subject).to receive(:send_event)
    allow(Raven::Event).to receive(:from_message) { event }
    allow(Raven::Event).to receive(:from_exception) { event }

    subject.configuration.dsn = "dummy://woopwoop"
  end

  describe '#context' do
    it 'is different than Raven.context'
  end

  describe '#capture_type' do
    describe 'as #capture_message' do
      let(:message) { "Test message" }

      it 'sends the result of Event.capture_message' do
        expect(Raven::Event).to receive(:from_message).with(message, options)
        expect(subject).to receive(:send_event).with(event)

        subject.capture_type(message, options)
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
        expect(Raven::Event).to receive(:from_message).with(message, options)
        expect(subject).not_to receive(:send_event).with(event)

        expect(subject.configuration.async).to receive(:call).with(event)
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
        expect(Raven::Event).to receive(:from_exception).with(exception, options)
        expect(subject).to receive(:send_event).with(event)

        subject.capture_type(exception, options)
      end

      it 'yields the event to a passed block' do
        expect { |b| subject.capture_type(exception, options, &b) }.to yield_with_args(event)
      end
    end

    describe 'as #capture_exception when async' do
      let(:exception) { build_exception }

      around do |example|
        prior_async = subject.configuration.async
        subject.configuration.async = proc { :ok }
        example.run
        subject.configuration.async = prior_async
      end

      it 'sends the result of Event.capture_exception' do
        expect(Raven::Event).to receive(:from_exception).with(exception, options)
        expect(subject).not_to receive(:send_event).with(event)

        expect(subject.configuration.async).to receive(:call).with(event)
        subject.capture_type(exception, options)
      end

      it 'returns the generated event' do
        returned = subject.capture_type(exception, options)
        expect(returned).to eq(event)
      end
    end

    describe 'as #capture_exception with a should_capture callback' do
      let(:exception) { build_exception }

      it 'sends the result of Event.capture_exception according to the result of should_capture' do
        expect(subject).not_to receive(:send_event).with(event)

        prior_should_capture = subject.configuration.should_capture
        subject.configuration.should_capture = proc { false }
        expect(subject.configuration.should_capture).to receive(:call).with(exception)
        expect(subject.capture_type(exception, options)).to be false
        subject.configuration.should_capture = prior_should_capture
      end
    end
  end

  describe '#capture' do
    context 'given a block' do
      it 'yields to the given block' do
        expect { |b| subject.capture(&b) }.to yield_with_no_args
      end
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
        receive(:capture_in_current_environment?).and_return(true)
      )
      expect(subject.logger).to receive(:info).with(ready_message)
      subject.report_status
    end

    it 'logs not ready message if the config does not send in current environment' do
      subject.configuration.silence_ready = false
      expect(subject.configuration).to(
        receive(:capture_in_current_environment?).and_return(false)
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
