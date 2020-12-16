return unless defined?(Rack)

require 'spec_helper'

RSpec.describe Sentry::RequestInterface do
  let(:exception) { ZeroDivisionError.new("divided by 0") }
  let(:additional_headers) { {} }
  let(:env) { Rack::MockRequest.env_for("/test", additional_headers) }
  let(:interface) { Sentry::RequestInterface.new }

  before do
    Sentry.init do |config|
      config.dsn = DUMMY_DSN
    end
  end

  it "removes ip address headers" do
    ip = "1.1.1.1"

    env.merge!(
      "REMOTE_ADDR" => ip,
      "HTTP_CLIENT_IP" => ip,
      "HTTP_X_REAL_IP" => ip,
      "HTTP_X_FORWARDED_FOR" => ip
    )

    interface.from_rack(env)

    expect(interface.env).to_not include("REMOTE_ADDR")
    expect(interface.headers.keys).not_to include("Client-Ip")
    expect(interface.headers.keys).not_to include("X-Real-Ip")
    expect(interface.headers.keys).not_to include("X-Forwarded-For")
  end

  it 'excludes non whitelisted params from rack env' do
    additional_env = { "random_param" => "text", "query_string" => "test" }
    new_env = env.merge(additional_env)
    interface.from_rack(new_env)

    expect(interface.env).to_not include(additional_env)
  end

  it 'formats rack env according to the provided whitelist' do
    Sentry.configuration.rack_env_whitelist = %w(random_param query_string)
    additional_env = { "random_param" => "text", "query_string" => "test" }
    new_env = env.merge(additional_env)
    interface.from_rack(new_env)

    expect(interface.env).to eq(additional_env)
  end

  it 'keeps the original env intact when an empty whitelist is provided' do
    Sentry.configuration.rack_env_whitelist = []
    interface.from_rack(env)

    expect(interface.env).to eq(env)
  end

  describe 'format headers' do
    let(:additional_headers) { { "HTTP_VERSION" => "HTTP/1.1", "HTTP_COOKIE" => "test", "HTTP_X_REQUEST_ID" => "12345678" } }

    it 'transforms headers to conform with the interface' do
      interface.from_rack(env)

      expect(interface.headers).to eq("Content-Length" => "0", "Version" => "HTTP/1.1", "X-Request-Id" => "12345678")
    end

    context 'from Rails middleware' do
      let(:additional_headers) { { "action_dispatch.request_id" => "12345678" } }

      it 'transforms headers to conform with the interface' do
        interface.from_rack(env)

        expect(interface.headers).to eq("Content-Length" => "0", "X-Request-Id" => "12345678")
      end
    end
  end

  it 'does not ignore version headers which do not match SERVER_PROTOCOL' do
    new_env = env.merge("SERVER_PROTOCOL" => "HTTP/1.1", "HTTP_VERSION" => "HTTP/2.0")

    interface.from_rack(new_env)

    expect(interface.headers["Version"]).to eq("HTTP/2.0")
  end

  it 'retains any literal "HTTP-" in the actual header name' do
    new_env = env.merge("HTTP_HTTP_CUSTOM_HTTP_HEADER" => "test")
    interface.from_rack(new_env)

    expect(interface.headers).to include("Http-Custom-Http-Header" => "test")
  end

  it 'does not fail if an object in the env cannot be cast to string' do
    obj = Class.new do
      def to_s
        raise 'Could not stringify object!'
      end
    end.new

    new_env = env.merge("HTTP_FOO" => "BAR", "rails_object" => obj)

    expect { interface.from_rack(new_env) }.to_not raise_error
  end

  it "doesn't capture cookies info" do
      new_env = env.merge(
        ::Rack::RACK_REQUEST_COOKIE_HASH => "cookies!"
      )

      interface.from_rack(new_env)

      expect(interface.cookies).to eq(nil)
  end

  context "with form data" do
    it "doesn't store request body by default" do
      new_env = env.merge(
        "REQUEST_METHOD" => "POST",
        ::Rack::RACK_INPUT => StringIO.new("data=ignore me")
      )

      interface.from_rack(new_env)

      expect(interface.data).to eq(nil)
    end
  end

  context "with request body" do
    it "doesn't store request body by default" do
      new_env = env.merge(::Rack::RACK_INPUT => StringIO.new("ignore me"))

      interface.from_rack(new_env)

      expect(interface.data).to eq(nil)
    end
  end

  context "with config.send_default_pii = true" do
    before do
      Sentry.configuration.send_default_pii = true
    end

    it "stores cookies" do
      new_env = env.merge(
        ::Rack::RACK_REQUEST_COOKIE_HASH => "cookies!"
      )

      interface.from_rack(new_env)

      expect(interface.cookies).to eq("cookies!")
    end

    it "stores form data" do
      new_env = env.merge(
        "REQUEST_METHOD" => "POST",
        ::Rack::RACK_INPUT => StringIO.new("data=catch me")
      )

      interface.from_rack(new_env)

      expect(interface.data).to eq({ "data" => "catch me" })
    end

    it "stores request body" do
      new_env = env.merge(::Rack::RACK_INPUT => StringIO.new("catch me"))

      interface.from_rack(new_env)

      expect(interface.data).to eq("catch me")
    end

    it "doesn't remove ip address headers" do
      ip = "1.1.1.1"

      env.merge!(
        "REMOTE_ADDR" => ip,
        "HTTP_CLIENT_IP" => ip,
        "HTTP_X_REAL_IP" => ip,
        "HTTP_X_FORWARDED_FOR" => ip
      )

      interface.from_rack(env)

      expect(interface.env).to include("REMOTE_ADDR")
      expect(interface.headers.keys).to include("Client-Ip")
      expect(interface.headers.keys).to include("X-Real-Ip")
      expect(interface.headers.keys).to include("X-Forwarded-For")
    end
  end
end
