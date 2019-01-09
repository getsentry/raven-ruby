require 'spec_helper'

RSpec.describe "Integration tests" do
  before(:each) do
    @io = StringIO.new
    @logger = Logger.new(@io)
    @instance = Raven::Instance.new
    @stubs = Faraday::Adapter::Test::Stubs.new
    @instance.configuration = Raven::Configuration.new.tap do |config|
      config.server = 'http://12345:67890@sentry.localdomain/sentry/42'
      config.http_adapter = [:test, @stubs]
      config.logger = @logger
    end
  end

  it "posting an exception" do
    @stubs.post('sentry/api/42/store/') { [200, {}, 'ok'] }

    @instance.capture_exception(build_exception)

    @stubs.verify_stubbed_calls
    expect(@io.string).to match(/Sending event [0-9a-f]+ to Sentry$/)
  end

  it "posting an exception to a prefixed DSN" do
    @stubs.post('/prefix/sentry/api/42/store/') { [200, {}, 'ok'] }
    @instance.configuration.server = 'http://12345:67890@sentry.localdomain/prefix/sentry/42'

    @instance.capture_exception(build_exception)

    @stubs.verify_stubbed_calls
  end

  # TODO: Not a very good test
  # it "hitting quota limit shouldn't swallow exception" do
  #   @stubs.post('sentry/api/42/store/') { [403, {}, 'Creation of this event was blocked'] }
  #
  #   # sentry error and original error
  #   expect(@logger).not_to receive(:error)
  #   @instance.capture_exception(build_exception)
  #
  #   @stubs.verify_stubbed_calls
  # end

  it "timed backoff should prevent sends" do
    expect(@instance.client.transport).to receive(:send_event).exactly(1).times.and_raise(Faraday::Error::ConnectionFailed, "conn failed")
    2.times { @instance.capture_exception(build_exception) }
    expect(@io.string).to match(/Failed to submit event: ZeroDivisionError: divided by 0$/)
  end

  it "transport failure should call transport_failure_callback" do
    @instance.configuration.transport_failure_callback = proc { |_e| @io.puts "OK!" }

    expect(@instance.client.transport).to receive(:send_event).exactly(1).times.and_raise(Faraday::Error::ConnectionFailed, "conn failed")
    @instance.capture_exception(build_exception)
    expect(@io.string).to match(/OK!$/)
  end

  it "define before_send and change event before sending" do
    @stubs.post('/prefix/sentry/api/42/store/') { [200, {}, 'ok'] }

    @instance.configuration.server = 'http://12345:67890@sentry.localdomain/prefix/sentry/42'
    @instance.configuration.before_send = lambda { |event, _hint|
      event[:environment] = 'test'
      event
    }

    @instance.capture_exception(build_exception)

    @stubs.verify_stubbed_calls
  end
end
