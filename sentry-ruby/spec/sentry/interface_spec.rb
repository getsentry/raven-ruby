require 'spec_helper'
require 'sentry/interface'

class TestInterface < Sentry::Interface
  attr_accessor :some_attr
end

RSpec.describe Sentry::Interface do
  it "should register an interface when a new class is defined" do
    expect(Sentry::Interface.registered[:test]).to eq(TestInterface)
  end

  it "can be initialized with some attributes" do
    interface = TestInterface.new(:some_attr => "test")
    expect(interface.some_attr).to eq("test")
  end

  it "can initialize with a block" do
    interface = TestInterface.new { |int| int.some_attr = "test" }
    expect(interface.some_attr).to eq("test")
  end

  it "serializes to a Hash" do
    interface = TestInterface.new(:some_attr => "test")
    expect(interface.to_hash).to eq(:some_attr => "test")
  end
end
