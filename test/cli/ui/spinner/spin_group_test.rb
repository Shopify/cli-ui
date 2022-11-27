require 'test_helper'

module CLI
  module UI
    module Spinner
      class SpinGroupTest < Minitest::Test
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

        def test_spin_group_success_debrief
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            debriefer = ->(title, out, err) {}
            sg = SpinGroup.new
            sg.success_debrief(&debriefer)
            debriefer.expects(:call).with('s', "Task output\n", '').once
            sg.add('s') do
              puts('Task output')
              true
            end

            assert(sg.wait)
          end
        end
      end
    end
  end
end
