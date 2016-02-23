require "spec_helper"
require "rspec/rails"
require "raven/transports/dummy"

describe TestApp, :type => :request do
  before(:all) do
    Raven.configure do |config|
      config.dsn = 'dummy://notaserver'
      config.encoding = 'json'
      config.logger = nil
    end
    Rails.env = "production"
    TestApp.initialize!
  end

  after(:each) do
    Raven.client.transport.events = []
  end

  it "inserts middleware" do
    expect(TestApp.middleware).to include(Raven::Rack)
  end

  it "should capture exceptions in production" do
    get "/exception"
    expect(response.status).to eq(500)
    expect(Raven.client.transport.events.size).to eq(1)
  end

  it "should properly set the exception's URL" do
    get "/exception"

    # TODO: dummy transport shouldn't even encode the event
    event = Raven.client.transport.events.first
    event = JSON.parse!(event[1])

    expect(event['request']['url']).to eq("http://www.example.com/exception")
  end

  it "sets Raven.configuration.logger correctly" do
    expect(Raven.configuration.logger).to eq(Rails.logger)
  end

  it "sets Raven.configuration.project_root correctly" do
    expect(Raven.configuration.project_root).to eq(Rails.root)
  end

  it "doesn't clobber a manually configured release" do
    expect(Raven.configuration.release).to eq('beta')
  end

  context "when catch_debugged_exceptions is disabled" do
    before do
      Raven.configure do |config|
        config.catch_debugged_exceptions = false
      end
    end

    after do
      Raven.configure do |config|
        config.catch_debugged_exceptions = true
      end
    end

    it "doesn't capture exceptions automatically" do
      get "/exception"
      expect(response.status).to eq(500)
      expect(Raven.client.transport.events.size).to eq(0)
    end
  end
end
