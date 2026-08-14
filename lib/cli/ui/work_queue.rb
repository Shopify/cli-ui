# typed: strict
# frozen_string_literal: true

module CLI
  module UI
    class WorkQueue
      # Locking invariants:
      # - @mutex protects @workers, @active_workers, and queue lifecycle changes.
      # - #start_worker and #prune_workers are called only while @mutex is held.
      # - Worker threads are never joined while @mutex is held.
      # - Queue code may acquire a Future mutex, but Future code never acquires
      #   the queue mutex.

      # Concurrency used when a caller explicitly requests no limit.
      UNLIMITED_CONCURRENCY = 1024 #: Integer

      # Raised into a future whose worker exited without settling it: Thread#raise
      # and Thread#kill can land outside the worker's rescues.
      class AbandonedTaskError < StandardError; end

      class Future
        #: -> void
        def initialize
          @mutex = Mutex.new #: Mutex
          @condition = ConditionVariable.new #: ConditionVariable
          @completed = false #: bool
          @started = false #: bool
          @result = nil #: untyped
          @error = nil #: Exception?
          @worker = nil #: Thread?
        end

        #: (untyped result) -> void
        def complete(result) # :nodoc:
          Thread.handle_interrupt(Exception => :never) do
            @mutex.synchronize do
              return if @completed

              @result = result
              @worker = nil
              @completed = true
              @condition.broadcast
            end
          end
        end

        #: (Exception error) -> void
        def fail(error) # :nodoc:
          Thread.handle_interrupt(Exception => :never) do
            @mutex.synchronize do
              return if @completed

              @error = error
              @worker = nil
              @completed = true
              @condition.broadcast
            end
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

        #: (?Thread? worker) -> bool
        def start(worker = nil) # :nodoc:
          Thread.handle_interrupt(Exception => :never) do
            @mutex.synchronize do
              return false if @completed

              @worker = worker
              @started = true
              @condition.broadcast
              true
            end
          end
        end

        #: (Thread interrupting_thread) -> Thread?
        def interrupt(interrupting_thread) # :nodoc:
          Thread.handle_interrupt(Exception => :never) do
            @mutex.synchronize do
              return if @completed

              worker = @worker
              error = Interrupt.new
              @error = error
              @worker = nil
              @completed = true
              @condition.broadcast

              # Deliver while holding the future lock. The worker cannot
              # complete this future and advance to unrelated work between
              # selecting it for interruption and receiving the exception.
              if worker && worker != interrupting_thread
                begin
                  worker.raise(error) if worker.alive?
                rescue ThreadError
                  # The worker exited between alive? and raise.
                end
              end

              worker
            end
          end
        end
      end

      #: (Integer max_concurrent) -> void
      def initialize(max_concurrent)
        raise ArgumentError, 'max_concurrent must be non-negative' if max_concurrent.negative?

        @max_concurrent = (max_concurrent.zero? ? UNLIMITED_CONCURRENCY : max_concurrent) #: Integer
        @queue = Queue.new #: Queue
        @mutex = Mutex.new #: Mutex
        @workers = [] #: Array[Thread]
        @active_workers = 0 #: Integer
      end

      #: { -> untyped } -> Future
      def enqueue(&block)
        future = Future.new
        @mutex.synchronize do
          prune_workers
          @queue.push([future, block])
          start_worker if @active_workers < @max_concurrent
        end
        future
      end

      #: -> void
      def close
        @mutex.synchronize { @queue.close }
      end

      #: -> void
      def wait
        close

        loop do
          workers = @mutex.synchronize { @workers.dup }
          break if workers.empty?

          # Do not rescue Interrupt here: a caller interrupting #wait should
          # observe it. Worker exceptions are contained by their lifecycle.
          workers.each(&:join)
          @mutex.synchronize { prune_workers }
        end
      end

      # Cancels selected futures without closing the queue or waiting for their
      # workers to unwind.
      #: (Array[Future] futures) -> void
      def cancel(futures)
        workers = futures.filter_map { |future| future.interrupt(Thread.current) }.uniq
        @mutex.synchronize { prune_workers }
        raise Interrupt if workers.include?(Thread.current)
      end

      #: -> void
      def interrupt
        workers = @mutex.synchronize do
          @queue.close
          # Fail any remaining tasks in the queue
          until @queue.empty?
            future, _block = @queue.pop(true)
            future&.fail(Interrupt.new)
          end
          @workers.dup
        end

        current_worker = workers.include?(Thread.current)
        other_workers = workers.reject { |worker| worker == Thread.current }

        # Interrupt worker threads without holding @mutex: workers retire under
        # that mutex, so joining them while holding it would deadlock.
        other_workers.each do |worker|
          worker.raise(Interrupt) if worker.alive?
        rescue ThreadError
          # The worker exited between alive? and raise.
        end

        other_workers.each do |worker|
          worker.join
        rescue Exception # rubocop:disable Lint/RescueException
          # Backstop: workers retire without propagating, and a late exception
          # must not replace what this thread is already propagating.
        end
        @mutex.synchronize { prune_workers }

        # Keep the worker history so #wait can still join the current worker
        # while it unwinds from the Interrupt raised below.
        raise Interrupt if current_worker
      end

      private

      #: -> void
      def prune_workers
        @workers.select!(&:alive?)
      end

      #: -> void
      def start_worker
        raise ThreadError, 'start_worker requires the queue mutex' unless @mutex.owned?

        worker = Thread.new do
          # Only task bodies are interruptible. Masking the dequeue handoff
          # prevents an asynchronous exception from removing work before its
          # future is known. Idle workers still wake when the queue is closed.
          Thread.handle_interrupt(Exception => :never) do
            loop do
              work = @queue.pop
              break if work.nil?

              future, block = work
              run_task(future, block)
            end
          end
        rescue Interrupt
          # Clean exit on interrupt
        rescue Exception # rubocop:disable Lint/RescueException
          # The future carries the exception to its caller. Fatal exceptions
          # terminate this worker; retirement replaces it if needed.
        ensure
          retire_worker
        end

        @workers << worker
        @active_workers += 1
      end

      # Runs one dequeued task to settlement on this worker.
      #: (Future future, ^() -> untyped block) -> void
      def run_task(future, block)
        return unless future.start(Thread.current)

        Thread.handle_interrupt(Exception => :immediate) do
          future.complete(block.call)
        end
      rescue StandardError, ScriptError => e
        # Recoverable task failures do not poison the worker.
        future.fail(e)
      rescue Exception => e # rubocop:disable Lint/RescueException
        future.fail(e)
        raise
      ensure
        # A worker must never abandon a future: an unsettled future blocks
        # Future#value forever. No-op once it is settled.
        future.fail(AbandonedTaskError.new('worker exited before completing this task'))
      end

      # Releases this worker's slot, replacing it while work remains.
      #: -> void
      def retire_worker
        # An asynchronous exception here would strand this worker's slot.
        Thread.handle_interrupt(Exception => :never) do
          @mutex.synchronize do
            @active_workers -= 1
            start_worker if @active_workers < @max_concurrent && !@queue.empty?
          end
        end
      rescue Exception # rubocop:disable Lint/RescueException
        # A worker never propagates: #wait joins on behalf of a caller who was
        # never interrupted.
      end
    end
  end
end
