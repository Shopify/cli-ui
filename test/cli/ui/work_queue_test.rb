# typed: false

require 'test_helper'
require 'cli/ui/work_queue'
require 'timeout'

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

      def test_script_error_completes_future_without_replacing_worker
        @work_queue = WorkQueue.new(1)
        failed_worker = nil
        failed = @work_queue.enqueue do
          failed_worker = Thread.current
          raise ScriptError, 'boom'
        end
        followup = @work_queue.enqueue { Thread.current }

        @work_queue.wait

        assert(failed.completed?, 'failing future should be completed')
        error = assert_raises(ScriptError) { failed.value }
        assert_equal('boom', error.message)
        assert(followup.completed?, 'subsequent task should run on the same worker')
        assert_same(failed_worker, followup.value)
        assert_empty(@work_queue.instance_variable_get(:@workers))
      end

      def test_script_errors_do_not_accumulate_dead_workers
        @work_queue = WorkQueue.new(4)

        begin
          futures = 200.times.map { @work_queue.enqueue { raise LoadError, 'boom' } }
          futures.each { |future| assert_raises(LoadError) { future.value } }

          workers = @work_queue.instance_variable_get(:@workers)
          assert_equal(4, workers.size)
          assert(workers.all?(&:alive?))
          assert_equal(4, @work_queue.instance_variable_get(:@active_workers))
        ensure
          @work_queue.interrupt
        end
      end

      def test_interrupt_cannot_abandon_work_returned_by_queue_pop
        popped = Queue.new
        release_pop = Queue.new
        queue = Class.new do
          def initialize(popped, release_pop)
            @queue = Queue.new
            @popped = popped
            @release_pop = release_pop
            @gate_return = true
          end

          def push(work)
            @queue.push(work)
          end

          def pop(non_block = false)
            work = @queue.pop(non_block)
            if @gate_return
              @gate_return = false
              @popped << true
              @release_pop.pop
            end
            work
          end

          def close
            @queue.close
          end

          def empty?
            @queue.empty?
          end
        end.new(popped, release_pop)
        @work_queue.instance_variable_set(:@queue, queue)

        future = @work_queue.enqueue { :ran }
        popped.pop
        interrupter = Thread.new { @work_queue.interrupt }
        interrupter.report_on_exception = false

        begin
          assert_nil(
            interrupter.join(0.1),
            'interrupt should wait until the popped work is associated with its future',
          )
        ensure
          release_pop << true
          Timeout.timeout(10) { interrupter.join }
        end

        assert(future.completed?, 'the popped future must be settled')
        assert_raises(Interrupt) { future.value }
      end

      def test_worker_retirement_survives_asynchronous_termination
        @work_queue = WorkQueue.new(1)
        started = Queue.new
        release_task = Queue.new
        future = @work_queue.enqueue do
          started << true
          release_task.pop
          :ran
        end
        started.pop

        mutex = @work_queue.instance_variable_get(:@mutex)
        queue = @work_queue.instance_variable_get(:@queue)
        worker = @work_queue.instance_variable_get(:@workers).first
        mutex.lock
        begin
          queue.close
          release_task << true
          Timeout.timeout(10) do
            sleep(0.001) until future.completed? && worker.status == 'sleep'
          end
          worker.raise(Interrupt)
        ensure
          mutex.unlock
        end

        Timeout.timeout(10) { @work_queue.wait }

        assert_equal(:ran, future.value)
        assert_equal(
          0,
          @work_queue.instance_variable_get(:@active_workers),
          'a terminated worker must still release its slot',
        )
      end

      def test_worker_exit_settles_its_future_and_replaces_the_worker
        @work_queue = WorkQueue.new(1)
        started = Queue.new
        exit_now = Queue.new
        abandoned = @work_queue.enqueue do
          started << true
          exit_now.pop
          Thread.exit
        end
        started.pop
        replacement = @work_queue.enqueue { :ran }
        exit_now << true

        Timeout.timeout(10) do
          @work_queue.wait

          assert(abandoned.completed?, 'a worker must never leave a future unsettled')
          assert_raises(WorkQueue::AbandonedTaskError) { abandoned.value }
          assert_equal(:ran, replacement.value)
        end
      end

      def test_zero_max_concurrent_uses_the_unlimited_default
        work_queue = WorkQueue.new(0)
        assert_equal(WorkQueue::UNLIMITED_CONCURRENCY, work_queue.instance_variable_get(:@max_concurrent))
        future = work_queue.enqueue { :ran }
        work_queue.wait

        assert_equal(:ran, future.value)
      end

      def test_negative_max_concurrent_raises
        error = assert_raises(ArgumentError) { WorkQueue.new(-1) }
        assert_equal('max_concurrent must be non-negative', error.message)
      end

      def test_future_settlement_is_idempotent
        completed = WorkQueue::Future.new
        completed.complete(:ran)
        completed.fail(Interrupt.new)
        assert_equal(:ran, completed.value)

        failed = WorkQueue::Future.new
        error = ScriptError.new('boom')
        failed.fail(error)
        failed.complete(:ran)
        assert_same(error, assert_raises(ScriptError) { failed.value })
      end

      def test_future_start_remains_compatible_without_a_worker_argument
        future = WorkQueue::Future.new

        assert(future.start)
        assert(future.started?)
      end

      def test_future_completion_defers_asynchronous_interrupt_until_settled
        entered = Queue.new
        release = Queue.new
        mutex = Class.new do
          def initialize(entered, release)
            @mutex = Mutex.new
            @entered = entered
            @release = release
            @gate = true
          end

          def synchronize
            @mutex.synchronize do
              if @gate
                @gate = false
                @entered << true
                @release.pop
              end
              yield
            end
          end
        end.new(entered, release)

        future = WorkQueue::Future.new
        future.instance_variable_set(:@mutex, mutex)
        worker = Thread.new do
          future.complete(:ran)
        rescue Interrupt
          :interrupted
        end

        entered.pop
        worker.raise(Interrupt)
        release << true

        assert_equal(:interrupted, worker.value)
        assert_equal(:ran, future.value)
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

      def test_interrupting_selected_futures_keeps_the_queue_usable
        @work_queue = WorkQueue.new(2)
        selected_started = Queue.new
        unrelated_started = Queue.new
        release_unrelated = Queue.new
        selected = @work_queue.enqueue do
          selected_started << true
          sleep(5)
        end
        unrelated = @work_queue.enqueue do
          unrelated_started << true
          release_unrelated.pop
          :unrelated
        end

        selected_started.pop
        unrelated_started.pop
        @work_queue.cancel([selected])

        assert_raises(Interrupt) { selected.value }
        release_unrelated << true
        followup = @work_queue.enqueue { :followup }
        @work_queue.wait
        assert_equal(:unrelated, unrelated.value)
        assert_equal(:followup, followup.value)
      end

      def test_interrupting_a_queued_future_prevents_it_from_running
        @work_queue = WorkQueue.new(1)
        blocker_started = Queue.new
        release_blocker = Queue.new
        ran = false
        blocker = @work_queue.enqueue do
          blocker_started << true
          release_blocker.pop
          :blocker
        end
        cancelled = @work_queue.enqueue { ran = true }

        blocker_started.pop
        @work_queue.cancel([cancelled])
        release_blocker << true
        followup = @work_queue.enqueue { :followup }
        @work_queue.wait

        assert_equal(:blocker, blocker.value)
        assert_raises(Interrupt) { cancelled.value }
        refute(ran)
        assert_equal(:followup, followup.value)
      end

      def test_scoped_interrupts_prune_retired_worker_history
        @work_queue = WorkQueue.new(1)

        20.times do
          started = Queue.new
          future = @work_queue.enqueue do
            started << true
            sleep(5)
          end
          started.pop
          @work_queue.cancel([future])

          Timeout.timeout(10) do
            loop do
              active_workers = @work_queue.instance_variable_get(:@active_workers)
              workers = @work_queue.instance_variable_get(:@workers)
              break if active_workers.zero? && workers.none?(&:alive?)

              sleep(0.001)
            end
          end
        end

        assert_equal(1, @work_queue.instance_variable_get(:@workers).size)
        followup = @work_queue.enqueue { :followup }
        assert_equal(1, @work_queue.instance_variable_get(:@workers).size)

        @work_queue.wait

        assert_equal(:followup, followup.value)
        assert_empty(@work_queue.instance_variable_get(:@workers))
      end

      def test_interrupting_a_future_cannot_land_on_the_next_task
        @work_queue = WorkQueue.new(1)
        selected_started = Queue.new
        release_selected = Queue.new
        interrupt_recorded = Queue.new
        finish_interrupt = Queue.new
        next_started = Queue.new
        release_next = Queue.new

        selected = @work_queue.enqueue do
          selected_started << true
          release_selected.pop
        end
        unrelated = @work_queue.enqueue do
          next_started << true
          release_next.pop
          :unrelated
        end

        selected.singleton_class.prepend(Module.new do
          define_method(:interrupt) do |interrupting_thread|
            worker = super(interrupting_thread)
            interrupt_recorded << true
            finish_interrupt.pop
            worker
          end
        end)

        selected_started.pop
        interrupter = Thread.new { @work_queue.cancel([selected]) }
        interrupt_recorded.pop
        release_selected << true
        next_started.pop
        finish_interrupt << true
        interrupter.join
        release_next << true
        @work_queue.wait

        assert_raises(Interrupt) { selected.value }
        assert_equal(:unrelated, unrelated.value)
      end

      def test_worker_can_interrupt_its_own_future_without_closing_the_queue
        @work_queue = WorkQueue.new(1)
        current_future = Queue.new
        selected = @work_queue.enqueue do
          @work_queue.cancel([current_future.pop])
        end
        unrelated = @work_queue.enqueue { :unrelated }
        current_future << selected

        Timeout.timeout(10) { @work_queue.wait }

        assert_raises(Interrupt) { selected.value }
        assert_equal(:unrelated, unrelated.value)
      end

      def test_interrupt_from_a_worker_interrupts_its_siblings
        @work_queue = WorkQueue.new(2)
        sibling_started = Queue.new
        interrupter = @work_queue.enqueue do
          sibling_started.pop
          @work_queue.interrupt
        end
        sibling = @work_queue.enqueue do
          sibling_started << true
          sleep(5)
        end

        Timeout.timeout(10) { @work_queue.wait }

        assert_raises(Interrupt) { interrupter.value }
        assert_raises(Interrupt) { sibling.value }
      end

      def test_wait_joins_a_worker_that_interrupts_the_queue_until_it_unwinds
        @work_queue = WorkQueue.new(1)
        unwinding = Queue.new
        release = Queue.new
        future = @work_queue.enqueue do
          @work_queue.interrupt
        ensure
          unwinding << true
          release.pop
        end

        unwinding.pop
        waiter = Thread.new { @work_queue.wait }

        begin
          assert_nil(waiter.join(0.1), 'wait should not return while the current worker is still unwinding')
        ensure
          release << true
          Timeout.timeout(10) { waiter.join }
        end

        assert_raises(Interrupt) { future.value }
      end
    end
  end
end
