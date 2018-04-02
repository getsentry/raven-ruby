require 'test_helper'

class StacktraceInterfaceTest < Raven::Test
  def setup
    line = OpenStruct.new(
      :lineno => 2,
      :to_s => "test/support/example_file.rb:2:in `my_method'",
      :path => "test/support/example_file.rb",
      :absolute_path => "#{Dir.pwd}/test/support/example_file.rb"
    )
    @frame = Raven::StacktraceInterface::Frame.new(:line => line)
  end
end
