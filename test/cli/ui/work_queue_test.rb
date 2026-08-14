# typed: false

require 'test_helper'
require 'timeout'
require 'cli/ui/work_queue'

module CLI
  module UI
    class WorkQueueTest < Minitest::Test
      def setup
        @work_queue = WorkQueue.new(2)
      end

      def test_enqueue_and_wait
        results = []
        futures = []
        mutex = Mutex.new

        futures << @work_queue.enqueue do
          sleep(0.1)
          mutex.synchronize { results << 1 }
          1
        end
        futures << @work_queue.enqueue do
          mutex.synchronize { results << 2 }
          2
        end
        futures << @work_queue.enqueue do
          mutex.synchronize { results << 3 }
          3
        end

        @work_queue.wait

        assert_equal([2, 3, 1], results)
        assert_equal([1, 2, 3], futures.map(&:value))
        assert(futures.all?(&:completed?))
      end

      def test_future_started
        startup_queue = Queue.new
        shutdown_queue = Queue.new
        future = @work_queue.enqueue do
          startup_queue.push(:started)
          shutdown_queue.pop # Block until signaled to continue
          42
        end

        refute(future.started?, 'not started')
        startup_queue.pop # Wait for task to actually start
        assert(future.started?, 'started')
        refute(future.completed?, 'not completed')

        shutdown_queue.push(:continue)
        @work_queue.wait
        assert(future.completed?, 'completed')
        assert_equal(42, future.value)
      end

      def test_future_error
        future = @work_queue.enqueue { raise StandardError, 'Test error' }

        @work_queue.wait

        assert(future.completed?)
        assert_raises(StandardError, 'Test error') { future.value }
      end

      def test_future_non_standard_error_completes_and_worker_continues
        @work_queue = WorkQueue.new(1)
        failed = @work_queue.enqueue { raise NotImplementedError, 'not implemented' }
        replacement = @work_queue.enqueue { :ran }

        @work_queue.wait

        assert(failed.completed?)
        error = assert_raises(NotImplementedError) { failed.value }
        assert_equal('not implemented', error.message)
        assert_equal(:ran, replacement.value)
      end

      def test_killed_worker_fails_its_future_and_runs_already_queued_work
        @work_queue = WorkQueue.new(1)
        started = Queue.new
        abandoned = @work_queue.enqueue do
          started.push(:started)
          sleep(30)
        end
        replacement = @work_queue.enqueue { :ran }

        started.pop
        @work_queue.instance_variable_get(:@workers).first.kill
        Timeout.timeout(5) { @work_queue.wait }

        error = assert_raises(WorkQueue::WorkerDied) { abandoned.value }
        assert_match(/died before its task completed/, error.message)
        assert_equal(:ran, replacement.value)
      end

      def test_task_interrupt_replaces_worker_for_already_queued_work
        @work_queue = WorkQueue.new(1)
        started = Queue.new
        release = Queue.new
        interrupted = @work_queue.enqueue do
          started.push(:started)
          release.pop
          raise Interrupt
        end

        started.pop
        replacement = @work_queue.enqueue { :ran }
        release.push(:continue)
        Timeout.timeout(5) { @work_queue.wait }

        assert_raises(Interrupt) { interrupted.value }
        assert_equal(:ran, replacement.value)
      end

      def test_max_concurrent
        max_concurrent = 2
        @work_queue = WorkQueue.new(max_concurrent)

        mutex = Mutex.new
        startup_queue = Queue.new
        shutdown_queue = Queue.new
        current_count = 0
        max_observed = 0

        10.times do
          @work_queue.enqueue do
            mutex.synchronize do
              current_count += 1
              max_observed = [max_observed, current_count].max
              startup_queue.push(:ready)
            end

            shutdown_queue.pop # Block until signaled to continue

            mutex.synchronize do
              current_count -= 1
            end
          end
        end

        # Wait for max_concurrent tasks to start
        max_concurrent.times { startup_queue.pop }

        # Let all tasks complete
        10.times { shutdown_queue.push(:continue) }
        @work_queue.wait

        assert_equal(
          max_concurrent,
          max_observed,
          "Expected maximum of #{max_concurrent} concurrent tasks, but observed #{max_observed}",
        )
      end

      def test_many_short_tasks
        count = 100
        futures = count.times.map do |i|
          @work_queue.enqueue { i * 2 }
        end

        @work_queue.wait

        assert_equal((0...count).map { |i| i * 2 }, futures.map(&:value))
      end

      def test_future_value_blocks_until_result_available
        startup_queue = Queue.new
        shutdown_queue = Queue.new

        future = @work_queue.enqueue do
          startup_queue.push(:ready)
          shutdown_queue.pop # Block until signaled to continue
          42
        end

        value_thread = Thread.new { future.value }

        # Wait for work thread to actually start
        startup_queue.pop

        assert(value_thread.alive?, 'Expected future.value to block')

        # Signal work thread to complete
        shutdown_queue.push(:continue)
        result = value_thread.value

        assert_equal(42, result, 'Expected future.value to return the correct result')
      end

      def test_interrupt
        startup_queue = Queue.new
        interrupted = false
        future = @work_queue.enqueue do
          startup_queue.push(:started)
          sleep(1)
          interrupted = true
        end

        startup_queue.pop # Wait for task to actually start
        @work_queue.interrupt

        assert_raises(Interrupt) { future.value }
        refute(interrupted, 'Task should not complete after interrupt')
        assert(future.completed?, 'Future should be marked as completed after interrupt')
      end
    end
  end
end
