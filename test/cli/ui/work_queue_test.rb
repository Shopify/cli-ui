# typed: false

require 'test_helper'
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
        future = @work_queue.enqueue do
          sleep(0.1)
          42
        end

        refute(future.started?)
        sleep(0.05)
        assert(future.started?)
        refute(future.completed?)

        @work_queue.wait

        assert(future.completed?)
        assert_equal(42, future.value)
      end

      def test_future_error
        future = @work_queue.enqueue { raise StandardError, 'Test error' }

        @work_queue.wait

        assert(future.completed?)
        assert_raises(StandardError, 'Test error') { future.value }
      end

      def test_max_concurrent
        max_concurrent = 2
        @work_queue = WorkQueue.new(max_concurrent)

        mutex = Mutex.new
        current_count = 0
        max_observed = 0

        10.times do
          @work_queue.enqueue do
            mutex.synchronize do
              current_count += 1
              max_observed = [max_observed, current_count].max
            end

            sleep(0.01) # Small delay to increase chance of concurrency

            mutex.synchronize do
              current_count -= 1
            end
          end
        end

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
        start_time = Time.now
        delay = 0.2
        future = @work_queue.enqueue do
          sleep(delay)
          42
        end

        # Start a new thread to call future.value
        value_thread = Thread.new { future.value }

        # Assert that the value_thread is alive (blocked) shortly after starting
        sleep(0.05)
        assert(value_thread.alive?, 'Expected future.value to block')

        # Wait for the future to complete
        result = value_thread.value

        end_time = Time.now
        elapsed_time = end_time - start_time

        assert_equal(42, result, 'Expected future.value to return the correct result')
        assert(elapsed_time >= delay, "Expected future.value to block for at least #{delay} seconds")
        assert(elapsed_time < delay + 0.1, 'Expected future.value to unblock soon after the task completes')
      end

      def test_interrupt
        interrupted = false
        future = @work_queue.enqueue do
          sleep(1)
          interrupted = true
        end

        sleep(0.1) # Give some time for the task to start
        @work_queue.interrupt

        assert_raises(Interrupt) { future.value }
        refute(interrupted, 'Task should not complete after interrupt')
        assert(future.completed?, 'Future should be marked as completed after interrupt')
      end
    end
  end
end
