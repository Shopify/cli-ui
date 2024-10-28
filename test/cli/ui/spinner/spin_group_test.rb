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

        def test_spin_group_with_custom_work_queue
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            work_queue = CLI::UI::WorkQueue.new(2)
            sg = SpinGroup.new(work_queue: work_queue)

            tasks_executed = 0
            3.times do |i|
              sg.add("Task #{i + 1}") do
                tasks_executed += 1
                sleep(0.1)
                true
              end
            end

            assert(sg.wait)
            assert_equal(3, tasks_executed)
          end
        end

        def test_spin_group_with_max_concurrent
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new(max_concurrent: 2)

            start_times = []
            3.times do |i|
              sg.add("Task #{i + 1}") do
                start_times << Time.now
                sleep(0.2)
                true
              end
            end

            assert(sg.wait)
            assert_equal(3, start_times.size)
            assert(start_times[2] - start_times[0] >= 0.2, 'Third task should start after the first one finishes')
          end
        end

        def test_spin_group_interrupt
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new
            task_completed = false
            task_interrupted = false

            # Use Queue for thread-safe signaling
            started_queue = Queue.new

            sg.add('Interruptible task') do
              started_queue.push(true)
              10.times { sleep(0.1) }
              task_completed = true
            rescue Interrupt
              task_interrupted = true
              raise
            end

            t = Thread.new { sg.wait }

            # Wait for task to start
            started_queue.pop
            sleep(0.1) # Small delay to ensure we're in sleep
            t.raise(Interrupt)
            sleep(0.1) # Small delay to react to Interrupt

            assert_raises(Interrupt) { t.join }
            refute(task_completed, 'Task should not have completed')
            assert(task_interrupted, 'Task should have been interrupted')
          end
        end
      end
    end
  end
end
