# frozen_string_literal: true

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

            startup_queue = Queue.new
            shutdown_queue = Queue.new
            tasks_executed = 0

            3.times do |i|
              sg.add("Task #{i + 1}") do
                tasks_executed += 1
                startup_queue.push(:started)
                shutdown_queue.pop
                true
              end
            end

            # Wait for first two tasks to start (since work_queue size is 2)
            2.times { startup_queue.pop }

            # Let first two tasks complete
            2.times { shutdown_queue.push(:continue) }

            # Now wait for the third task to start and complete
            startup_queue.pop
            shutdown_queue.push(:continue)

            assert(sg.wait)
            assert_equal(3, tasks_executed)
          end
        end

        def test_spin_group_with_max_concurrent
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new(max_concurrent: 2)

            startup_queue = Queue.new
            shutdown_queue = Queue.new
            task_count = 3

            task_count.times do |i|
              sg.add("Task #{i + 1}") do
                startup_queue.push(:started)
                shutdown_queue.pop
                true
              end
            end

            # Wait for first two tasks to start
            2.times { startup_queue.pop }

            # Third task shouldn't have started yet
            assert_equal(0, startup_queue.size, 'Third task should not have started')

            # Let first task complete
            shutdown_queue.push(:continue)

            # Wait for third task to start
            startup_queue.pop

            # Let remaining tasks complete
            2.times { shutdown_queue.push(:continue) }

            assert(sg.wait)
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
              sleep(1)
              task_completed = true
            rescue Interrupt
              task_interrupted = true
              raise
            end

            t = Thread.new { sg.wait }
            t.report_on_exception = false

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

        def test_spin_group_exceptions
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new

            sg.add('Just a task') do
            end

            sg.add('Raising task') do
              raise 'Error'
            end

            t = Thread.new { sg.wait }

            t.join

            assert_equal(['Error'], sg.all_exceptions.map(&:message))
          end
        end

        def test_spin_group_stop
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new

            task_started = false
            task_completed = false

            sg.add('Stoppable task') do
              task_started = true
              sleep(1)
              task_completed = true
            end

            t = Thread.new { sg.wait }

            # Wait for task to start
            sleep(0.1) until task_started

            # Stop the spin group
            sg.stop

            t.join

            refute(task_completed, 'Task should not complete after stop')
            assert(sg.stopped?, 'SpinGroup should be marked as stopped')
            refute(sg.all_succeeded?, 'Tasks should not be marked as succeeded after stop')
          end
        end

        def test_spin_group_nested_stop
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new

            sg.add('Outer task') do
              sg.stop
              true
            end

            refute(sg.wait, 'SpinGroup#wait should return false when stopped')
            assert(sg.stopped?, 'SpinGroup should be marked as stopped')
          end
        end

        def test_spin_group_interrupt_with_debrief
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new(interrupt_debrief: true)
            task_interrupted = false
            debrief_called = false

            # Use Queue for thread-safe signaling
            started_queue = Queue.new

            sg.failure_debrief do |title, _exception, _out, _err|
              assert_equal('Failed task', title)
              debrief_called = true
            end

            sg.add('Failed task') do
              TASK_FAILED
            end

            sg.add('Interruptible task') do
              started_queue.push(true)
              sleep(1)
            rescue Interrupt
              task_interrupted = true
              raise
            end

            t = Thread.new { sg.wait }
            t.report_on_exception = false

            # Wait for task to start
            started_queue.pop
            sleep(0.1) # Small delay to ensure we're in sleep
            t.raise(Interrupt)

            # The interrupt should propagate since we didn't stop
            assert_raises(Interrupt) { t.join }
            assert(task_interrupted, 'Task should have been interrupted')
            assert(debrief_called, 'Debrief should have been called')
          end
        end

        def test_spin_group_interrupt_without_debrief
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new(interrupt_debrief: false)

            # Use Queue for thread-safe signaling
            started_queue = Queue.new

            debrief_called = false
            sg.failure_debrief do
              debrief_called = true
            end

            sg.add('Failed task') do
              TASK_FAILED
            end
            sg.add('Interruptible task') do
              started_queue.push(true)
              sleep(1)
              false
            end

            t = Thread.new { sg.wait }
            t.report_on_exception = false

            # Wait for task to actually start
            started_queue.pop
            sleep(0.1) # Small delay to ensure we're in sleep

            # Interrupt should be raised through
            t.raise(Interrupt)
            assert_raises(Interrupt) { t.join }

            refute(debrief_called, 'failure_debrief should not be called when interrupt_debrief is false')
          end
        end

        def test_task_on_done_callback
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            sg = SpinGroup.new

            callback_executed = false
            task_completed = false

            sg.add('Task with callback') do |task|
              task.on_done do |completed_task|
                callback_executed = true
                assert_equal('Task with callback', completed_task.title)
                assert(completed_task.done)
                assert(completed_task.success)
              end
              task_completed = true
              true
            end

            assert(sg.wait)
            assert(task_completed, 'Task should have completed')
            assert(callback_executed, 'on_done callback should have been executed')
          end
        end
      end
    end
  end
end
