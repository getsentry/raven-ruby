# Encoding: utf-8

require 'spec_helper'

describe Raven::Processor::PostData do
  before do
    @client = double("client")
    @processor = Raven::Processor::PostData.new(@client)
  end

  it 'should remove post data when HTTP method is POST' do
    data = {
      :request => {
        :method => "POST",
        :data => {
          "sensitive_stuff" => "TOP_SECRET-GAMMA"
        }
      }
    }

    result = @processor.process(data)

    expect(result[:request][:data]).to eq(nil)
  end

  it 'should remove post data when HTTP method is not POST' do
    data = {
      :request => {
        :method => "GET",
        :data => {
          "sensitive_stuff" => "TOP_SECRET-GAMMA"
        }
      }
    }

    result = @processor.process(data)

    expect(result[:request][:data]).to eq("sensitive_stuff" => "TOP_SECRET-GAMMA")
  end
end
