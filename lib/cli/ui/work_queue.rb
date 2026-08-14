# typed: strict
# frozen_string_literal: true

module CLI
  module UI
    class WorkQueue
      # Settled into a future whose worker left without settling it itself.
      class WorkerDied < StandardError
      end

      class Future
        #: -> void
        def initialize
          @mutex = Mutex.new #: Mutex
          @condition = ConditionVariable.new #: ConditionVariable
          @completed = false #: bool
          @started = false #: bool
          @result = nil #: untyped
          @error = nil #: Exception?
        end

        #: (untyped result) -> void
        def complete(result)
          @mutex.synchronize do
            @completed = true
            @result = result
            @condition.broadcast
          end
        end

        #: (Exception error) -> void
        def fail(error)
          @mutex.synchronize do
            return if @completed

            @completed = true
            @error = error
            @condition.broadcast
          end
        end

        #: -> untyped
        def value
          @mutex.synchronize do
            @condition.wait(@mutex) until @completed
            raise @error if @error

            @result
          end
        end

        #: -> bool
        def completed?
          @mutex.synchronize { @completed }
        end

        #: -> bool
        def started?
          @mutex.synchronize { @started }
        end

        #: -> void
        def start
          @mutex.synchronize do
            @started = true
            @condition.broadcast
          end
        end
      end

      #: (Integer max_concurrent) -> void
      def initialize(max_concurrent)
        @max_concurrent = max_concurrent
        @queue = Queue.new #: Queue
        @mutex = Mutex.new #: Mutex
        @interrupt_mutex = Mutex.new #: Mutex
        @condition = ConditionVariable.new #: ConditionVariable
        @workers = [] #: Array[Thread]
        @stopping = false #: bool
      end

      #: { -> untyped } -> Future
      def enqueue(&block)
        future = Future.new
        @mutex.synchronize do
          @queue.push([future, block])
          start_worker if @workers.size < @max_concurrent
        end
        future
      end

      #: -> void
      def close
        @queue.close
      end

      #: -> void
      def wait
        @queue.close
        loop do
          workers = @mutex.synchronize { @workers.dup }
          break if workers.empty?

          workers.each(&:join)
        end
      end

      #: -> void
      def interrupt
        @interrupt_mutex.synchronize do
          workers = @mutex.synchronize do
            @stopping = true
            @queue.close

            # Fail any remaining tasks in the queue. Workers can consume from
            # the queue concurrently, so an empty? check followed by pop is racy.
            loop do
              future, _block = @queue.pop(true)
              future&.fail(Interrupt.new)
            rescue ThreadError
              break
            end

            @workers.dup
          end

          # These are WorkQueue-owned threads being deliberately torn down, so
          # neither their thread-death report nor their Interrupt belongs to the
          # caller performing the teardown.
          workers.each do |worker|
            next unless worker.alive?

            worker.report_on_exception = false
            worker.raise(Interrupt)
          end
          workers.each do |worker|
            worker.join
          rescue Interrupt
            nil
          end
        ensure
          @mutex.synchronize { @workers.clear }
        end
      end

      private

      #: -> void
      def start_worker
        @workers << Thread.new do
          run_worker
        rescue Interrupt
          # Clean exit on interrupt
        ensure
          worker_finished(Thread.current)
        end
      end

      #: -> void
      def run_worker
        loop do
          future = nil #: Future?
          begin
            # Do not let an asynchronous exception land after Queue#pop has
            # removed work but before its future is assigned. Interrupts remain
            # enabled while pop is blocked and while the task itself is running.
            Thread.handle_interrupt(Exception => :never) do
              work = Thread.handle_interrupt(Exception => :on_blocking) { @queue.pop }
              return if work.nil?

              future, block = work
              future.start
              result = Thread.handle_interrupt(Exception => :immediate) { block.call }
              future.complete(result)
            end
          rescue Interrupt => e
            future&.fail(e)
            raise # Always re-raise interrupts to terminate the worker
          rescue Exception => e # rubocop:disable Lint/RescueException
            # The future carries the error to callers. Keep the worker: tasks
            # already queued may have no later enqueue to replace it.
            future&.fail(e)
          ensure
            if future
              Thread.handle_interrupt(Exception => :never) do
                unless future.completed?
                  future.fail(WorkerDied.new('worker died before its task completed'))
                end
              end
            end
          end
        end
      end

      #: (Thread worker) -> void
      def worker_finished(worker)
        Thread.handle_interrupt(Exception => :never) do
          @mutex.synchronize do
            @workers.delete(worker)
            if !@stopping && !@queue.empty? && @workers.size < @max_concurrent
              start_worker
            end
          end
        end
      end
    end
  end
end
