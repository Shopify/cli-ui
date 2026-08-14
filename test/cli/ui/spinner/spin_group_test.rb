# frozen_string_literal: true

require 'test_helper'
require 'timeout'

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

        def test_spin_group_non_standard_error_is_reported_as_a_task_failure
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            failures = []
            sibling_ran = false

            sg = SpinGroup.new
            sg.failure_debrief { |title, exception, _out, _err| failures << [title, exception] }
            sg.add('raises') { raise NotImplementedError, 'not done yet' }
            sg.add('sibling') { sibling_ran = true }

            # Before WorkQueue settled futures for non-StandardError exceptions
            # this spun forever; the timeout keeps a regression from wedging the
            # suite instead of failing it.
            refute(Timeout.timeout(10) { sg.wait })

            assert(sibling_ran, 'sibling task should still run to completion')
            assert_equal(1, failures.size)
            title, error = failures.first
            assert_equal('raises', title)
            assert_instance_of(NotImplementedError, error)
            assert_equal('not done yet', error.message)
          end
        end

        def test_spin_group_system_exit_propagates_and_interrupts_remaining_work
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            slow_started = Queue.new
            interrupted = Queue.new
            unwound = Queue.new
            sg = SpinGroup.new(auto_debrief: false)
            sg.add('exits') do
              slow_started.pop
              exit(1)
            end
            sg.add('slow') do
              slow_started << true
              sleep(5)
            rescue Interrupt
              interrupted << true
              raise
            ensure
              unwound << true
            end

            error = Timeout.timeout(10) { assert_raises(SystemExit) { sg.wait } }

            assert_equal(1, error.status)
            assert(Timeout.timeout(1) { interrupted.pop }, 'remaining workers should observe Interrupt')
            refute(unwound.empty?, 'remaining workers should unwind before wait raises')
          end
        end

        def test_spin_group_zero_max_concurrent_uses_the_default
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new(max_concurrent: 0, auto_debrief: false)
            work_queue = sg.instance_variable_get(:@work_queue)
            assert_equal(
              WorkQueue::UNLIMITED_CONCURRENCY,
              work_queue.instance_variable_get(:@max_concurrent),
            )
            sg.add('s') { true }

            assert(Timeout.timeout(10) { sg.wait })
          end
        end

        def test_spin_group_negative_max_concurrent_raises
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            error = assert_raises(ArgumentError) { SpinGroup.new(max_concurrent: -1) }
            assert_equal('max_concurrent must be non-negative', error.message)
          end
        end

        def test_spin_group_system_exit_interrupts_its_tasks_without_closing_a_shared_work_queue
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            work_queue = WorkQueue.new(3)
            unrelated_started = Queue.new
            release_unrelated = Queue.new
            unrelated = work_queue.enqueue do
              unrelated_started << true
              release_unrelated.pop
              :unrelated
            end

            slow_started = Queue.new
            interrupted = Queue.new
            sg = SpinGroup.new(auto_debrief: false, work_queue: work_queue)
            sg.add('exits') do
              slow_started.pop
              exit(1)
            end
            sg.add('slow') do
              slow_started << true
              sleep(5)
            rescue Interrupt
              interrupted << true
              raise
            end

            unrelated_started.pop
            assert_raises(SystemExit) { sg.wait }
            assert(Timeout.timeout(1) { interrupted.pop }, 'remaining group tasks should observe Interrupt')

            release_unrelated << true
            followup = work_queue.enqueue { :ran }
            work_queue.wait
            assert_equal(:unrelated, unrelated.value)
            assert_equal(:ran, followup.value)
          end
        end

        def test_stop_from_on_done_does_not_deadlock_a_shared_work_queue
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            work_queue = WorkQueue.new(2)
            cleanup_started = Queue.new
            cleanup_unwound = Queue.new
            sg = SpinGroup.new(auto_debrief: false, work_queue: work_queue)
            sg.add('stopper') do |task|
              task.on_done { sg.stop }
              cleanup_started.pop
              true
            end
            sg.add('cleanup') do
              cleanup_started << true
              sleep(5)
            ensure
              sg.puts_above('cleanup finished')
              cleanup_unwound << true
            end

            refute(Timeout.timeout(10) { sg.wait })
            assert(Timeout.timeout(1) { cleanup_unwound.pop })

            followup = work_queue.enqueue { :ran }
            work_queue.wait
            assert_equal(:ran, followup.value)
          end
        end

        def test_stop_from_on_done_does_not_deadlock_an_internal_work_queue
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            cleanup_started = Queue.new
            cleanup_unwound = Queue.new
            sg = SpinGroup.new(auto_debrief: false, max_concurrent: 2)
            sg.add('stopper') do |task|
              task.on_done { sg.stop }
              cleanup_started.pop
              true
            end
            sg.add('cleanup') do
              cleanup_started << true
              sleep(5)
            ensure
              sg.puts_above('cleanup finished')
              cleanup_unwound << true
            end

            refute(Timeout.timeout(10) { sg.wait })
            assert(Timeout.timeout(1) { cleanup_unwound.pop })
          end
        end

        def test_spin_group_stop_interrupts_its_tasks_without_closing_a_shared_work_queue
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            work_queue = WorkQueue.new(1)
            started = Queue.new
            interrupted = Queue.new
            completed = false
            sg = SpinGroup.new(auto_debrief: false, work_queue: work_queue)
            sg.add('slow') do
              started << true
              sleep(5)
              completed = true
            rescue Interrupt
              interrupted << true
              raise
            end

            waiter = Thread.new { sg.wait }
            started.pop
            sg.stop

            refute(Timeout.timeout(10) { waiter.value })
            assert(Timeout.timeout(1) { interrupted.pop }, 'the group task should observe Interrupt')
            followup = work_queue.enqueue { :ran }
            work_queue.wait
            refute(completed, 'the stopped group task should not complete')
            assert_equal(:ran, followup.value)
          end
        end

        def test_spin_group_interrupt_interrupts_its_tasks_without_closing_a_shared_work_queue
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            work_queue = WorkQueue.new(1)
            started = Queue.new
            interrupted = Queue.new
            completed = false
            sg = SpinGroup.new(auto_debrief: false, work_queue: work_queue)
            sg.add('slow') do
              started << true
              sleep(5)
              completed = true
            rescue Interrupt
              interrupted << true
              raise
            end

            waiter = Thread.new { sg.wait }
            waiter.report_on_exception = false
            started.pop
            waiter.raise(Interrupt)

            assert_raises(Interrupt) { waiter.join }
            assert(Timeout.timeout(1) { interrupted.pop }, 'the group task should observe Interrupt')
            followup = work_queue.enqueue { :ran }
            work_queue.wait
            refute(completed, 'the interrupted group task should not complete')
            assert_equal(:ran, followup.value)
          end
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

        def test_external_stop_waits_for_internal_workers_to_unwind
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            started = Queue.new
            cleanup_started = Queue.new
            release_cleanup = Queue.new
            sg = SpinGroup.new(auto_debrief: false)
            sg.add('cleanup') do
              started << true
              sleep(5)
            ensure
              cleanup_started << true
              release_cleanup.pop
            end

            waiter = Thread.new { sg.wait }
            Timeout.timeout(10) { started.pop }
            stopper = Thread.new { sg.stop }
            Timeout.timeout(10) { cleanup_started.pop }

            begin
              assert_nil(stopper.join(0.1), 'external stop should wait for worker cleanup')
            ensure
              release_cleanup << true
              Timeout.timeout(10) do
                stopper.join
                waiter.join
              end
            end
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

        def test_task_on_done_callback_may_reenter_the_group
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new(auto_debrief: false)
            sg.add('reenters') do |task|
              task.on_done do
                SpinGroup.pause_spinners { nil }
                sg.puts_above('from the callback')
              end
              true
            end

            assert(Timeout.timeout(10) { sg.wait })
          end
        end

        def test_success_debrief_callback_may_reenter_the_group
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new
            sg.success_debrief do
              SpinGroup.pause_spinners { nil }
              sg.puts_above('from the debrief')
            end
            sg.add('succeeds') { true }

            assert(Timeout.timeout(10) { sg.wait })
          end
        end

        def test_stop_from_a_final_glyph_defers_join_until_outside_the_render_mutex
          capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            cleanup_started = Queue.new
            cleanup_unwound = Queue.new
            sg = SpinGroup.new(auto_debrief: false, max_concurrent: 2)
            stopping_glyph = lambda do |_success|
              sg.stop
              CLI::UI::Glyph::CHECK
            end
            sg.add('stopper', final_glyph: stopping_glyph) do
              cleanup_started.pop
              true
            end
            sg.add('cleanup') do
              cleanup_started << true
              sleep(5)
            ensure
              sg.puts_above('cleanup finished')
              cleanup_unwound << true
            end

            refute(Timeout.timeout(10) { sg.wait })
            assert(Timeout.timeout(1) { cleanup_unwound.pop })
          end
        end
      end
    end
  end
end
