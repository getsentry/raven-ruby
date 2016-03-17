# Encoding: utf-8

require 'spec_helper'

describe Raven::Processor::Cookies do
  before do
    @client = double("client")
    @processor = Raven::Processor::Cookies.new(@client)
  end

  it 'should remove cookies' do
    data = {
      :request => {
        :headers => {
          "Cookie" => "_sentry-testapp_session=SlRKVnNha2Z",
          "AnotherHeader" => "still_here"
        },
        :cookies => "_sentry-testapp_session=SlRKVnNha2Z",
        :some_other_data => "still_here"
      }
    }

    result = @processor.process(data)

    expect(result[:request][:cookies]).to eq(nil)
    expect(result[:request][:headers]["Cookie"]).to eq(nil)
    expect(result[:request][:some_other_data]).to eq("still_here")
    expect(result[:request][:headers]["AnotherHeader"]).to eq("still_here")
  end
end
