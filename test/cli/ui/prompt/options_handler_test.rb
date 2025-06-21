# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    module Prompt
      class OptionsHandlerTest < Minitest::Test
        def test_initialize
          handler = OptionsHandler.new

          assert_empty(handler.options)
        end

        def test_option
          handler = OptionsHandler.new

          handler.option('a') {}
          handler.option('b') {}
          handler.option('c') {}

          assert_equal(['a', 'b', 'c'], handler.options)
        end

        def test_call
          handler = OptionsHandler.new
          procedure_called = false
          procedure = proc do |selection|
            procedure_called = true
            selection
          end

          handler.option('a', &procedure)
          assert_equal('a', handler.call('a'))
          assert(procedure_called)
        end
      end
    end
  end
end
