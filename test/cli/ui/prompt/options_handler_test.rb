require 'test_helper'
require 'cli/ui/prompt/options_handler'

module CLI
  module UI
    module Prompt
      class OptionsHandlerTest < MiniTest::Test
        def test_initialize
          handler = OptionsHandler.new

          assert_empty handler.options
        end

        def test_add_option
          handler = OptionsHandler.new

          handler.add_option('a') {}
          handler.add_option('b') {}
          handler.add_option('c') {}

          assert_equal ['a', 'b', 'c'], handler.options
        end

        def test_call
          handler = OptionsHandler.new
          procedure_called = false
          procedure = Proc.new do |selection|
            procedure_called = true
            selection
          end

          handler.add_option('a', &procedure)
          assert_equal 'a', handler.call('a')
          assert procedure_called
        end
      end
    end
  end
end
