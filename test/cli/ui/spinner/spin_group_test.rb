require 'test_helper'

module CLI
  module UI
    module Spinner
      class SpinGroupTest < MiniTest::Test
        def test_spin_group
          _out, err = capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new
            sg.add('s') do
              true
            end

            assert(sg.wait)
          end

          assert_equal('', err)
        end

        def test_spin_group_auto_debrief_false
          _out, err = capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new(auto_debrief: false)
            sg.add('s') do
              true
            end

            assert(sg.wait)
          end

          assert_equal('', err)
        end
      end
    end
  end
end
