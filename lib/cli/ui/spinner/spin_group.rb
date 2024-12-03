# typed: true
# frozen_string_literal: true

require_relative '../work_queue'

module CLI
  module UI
    module Spinner
      class SpinGroup
        DEFAULT_FINAL_GLYPH = ->(success) { success ? CLI::UI::Glyph::CHECK : CLI::UI::Glyph::X }

        class << self
          extend T::Sig

          sig { returns(Mutex) }
          attr_reader :pause_mutex

          sig { returns(T::Boolean) }
          def paused?
            @paused
          end

          sig do
            type_parameters(:T)
              .params(block: T.proc.returns(T.type_parameter(:T)))
              .returns(T.type_parameter(:T))
          end
          def pause_spinners(&block)
            previous_paused = T.let(nil, T.nilable(T::Boolean))
            @pause_mutex.synchronize do
              previous_paused = @paused
              @paused = true
            end
            block.call
          ensure
            @pause_mutex.synchronize do
              @paused = previous_paused
            end
          end
        end

        @pause_mutex = Mutex.new
        @paused = false

        extend T::Sig

        # Initializes a new spin group
        # This lets you add +Task+ objects to the group to multi-thread work
        #
        # ==== Options
        #
        # * +:auto_debrief+ - Automatically debrief exceptions or through success_debrief? Default to true
        # * +:interrupt_debrief+ - Automatically debrief on interrupt. Default to false
        # * +:max_concurrent+ - Maximum number of concurrent tasks. Default is 0 (effectively unlimited)
        # * +:work_queue+ - Custom WorkQueue instance. If not provided, a new one will be created
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout
        #
        # ==== Example Usage
        #
        #  CLI::UI::SpinGroup.new do |spin_group|
        #    spin_group.add('Title')   { |spinner| sleep 3.0 }
        #    spin_group.add('Title 2') { |spinner| sleep 3.0; spinner.update_title('New Title'); sleep 3.0 }
        #  end
        #
        # Output:
        #
        # https://user-images.githubusercontent.com/3074765/33798558-c452fa26-dce8-11e7-9e90-b4b34df21a46.gif
        #
        sig do
          params(
            auto_debrief: T::Boolean,
            interrupt_debrief: T::Boolean,
            max_concurrent: Integer,
            work_queue: T.nilable(WorkQueue),
            to: IOLike,
          ).void
        end
        def initialize(auto_debrief: true, interrupt_debrief: false, max_concurrent: 0, work_queue: nil, to: $stdout)
          @m = Mutex.new
          @tasks = []
          @puts_above = []
          @auto_debrief = auto_debrief
          @interrupt_debrief = interrupt_debrief
          @start = Time.new
          @stopped = false
          @internal_work_queue = work_queue.nil?
          @work_queue = T.let(
            work_queue || WorkQueue.new(max_concurrent.zero? ? 1024 : max_concurrent),
            WorkQueue,
          )
          if block_given?
            yield self
            wait(to: to)
          end
        end

        class Task
          extend T::Sig

          sig { returns(String) }
          attr_reader :title, :stdout, :stderr

          sig { returns(T::Boolean) }
          attr_reader :success

          sig { returns(T::Boolean) }
          attr_reader :done

          sig { returns(T.nilable(Exception)) }
          attr_reader :exception

          # Initializes a new Task
          # This is managed entirely internally by +SpinGroup+
          #
          # ==== Attributes
          #
          # * +title+ - Title of the task
          # * +block+ - Block for the task, will be provided with an instance of the spinner
          #
          sig do
            params(
              title: String,
              final_glyph: T.proc.params(success: T::Boolean).returns(T.any(Glyph, String)),
              merged_output: T::Boolean,
              duplicate_output_to: IO,
              work_queue: WorkQueue,
              block: T.proc.params(task: Task).returns(T.untyped),
            ).void
          end
          def initialize(title, final_glyph:, merged_output:, duplicate_output_to:, work_queue:, &block)
            @title = title
            @final_glyph = final_glyph
            @always_full_render = title =~ Formatter::SCAN_WIDGET
            @future = work_queue.enqueue do
              cap = CLI::UI::StdoutRouter::Capture.new(
                merged_output: merged_output, duplicate_output_to: duplicate_output_to,
              ) { block.call(self) }
              begin
                cap.run
              ensure
                @stdout = cap.stdout
                @stderr = cap.stderr
              end
            end

            @m = Mutex.new
            @force_full_render = false
            @done = false
            @exception = nil
            @success = false
          end

          sig { params(block: T.proc.params(task: Task).void).void }
          def on_done(&block)
            @on_done = block
          end

          # Checks if a task is finished
          #
          sig { returns(T::Boolean) }
          def check
            return true if @done
            return false unless @future.completed?

            @done = true
            begin
              result = @future.value
              @success = true
              @success = false if result == TASK_FAILED
            rescue => exc
              @exception = exc
              @success = false
            end

            @on_done&.call(self)

            @done
          end

          # Re-renders the task if required:
          #
          # We try to be as lazy as possible in re-rendering the full line. The
          # spinner rune will change on each render for the most part, but the
          # body text will rarely have changed. If the body text *has* changed,
          # we set @force_full_render.
          #
          # Further, if the title string includes any CLI::UI::Widgets, we
          # assume that it may change from render to render, since those
          # evaluate more dynamically than the rest of our format codes, which
          # are just text formatters. This is controlled by @always_full_render.
          #
          # ==== Attributes
          #
          # * +index+ - index of the task
          # * +force+ - force rerender of the task
          # * +width+ - current terminal width to format for
          #
          sig { params(index: Integer, force: T::Boolean, width: Integer).returns(String) }
          def render(index, force = true, width: CLI::UI::Terminal.width)
            @m.synchronize do
              if !CLI::UI.enable_cursor? || force || @always_full_render || @force_full_render
                full_render(index, width)
              else
                partial_render(index)
              end
            ensure
              @force_full_render = false
            end
          end

          # Update the spinner title
          #
          # ==== Attributes
          #
          # * +title+ - title to change the spinner to
          #
          sig { params(new_title: String).void }
          def update_title(new_title)
            @m.synchronize do
              @always_full_render = new_title =~ Formatter::SCAN_WIDGET
              @title = new_title
              @force_full_render = true
            end
          end

          private

          sig { params(index: Integer, terminal_width: Integer).returns(String) }
          def full_render(index, terminal_width)
            o = +''

            o << inset
            o << glyph(index)
            o << ' '

            truncation_width = terminal_width - CLI::UI::ANSI.printing_width(o)

            o << CLI::UI.resolve_text(title, truncate_to: truncation_width)
            o << ANSI.clear_to_end_of_line if CLI::UI.enable_cursor?

            o
          end

          sig { params(index: Integer).returns(String) }
          def partial_render(index)
            o = +''

            o << CLI::UI::ANSI.cursor_forward(inset_width)
            o << glyph(index)

            o
          end

          sig { params(index: Integer).returns(String) }
          def glyph(index)
            if @done
              final_glyph = @final_glyph.call(@success)
              if final_glyph.is_a?(Glyph)
                CLI::UI.enable_color? ? final_glyph.to_s : final_glyph.char
              else
                final_glyph
              end
            elsif CLI::UI.enable_cursor?
              if !@future.started?
                CLI::UI.enable_color? ? Glyph::HOURGLASS.to_s : Glyph::HOURGLASS.char
              else
                CLI::UI.enable_color? ? GLYPHS[index] : RUNES[index]
              end
            else
              Glyph::HOURGLASS.char
            end
          end

          sig { returns(String) }
          def inset
            @inset ||= CLI::UI::Frame.prefix
          end

          sig { returns(Integer) }
          def inset_width
            @inset_width ||= CLI::UI::ANSI.printing_width(inset)
          end
        end

        # Add a new task
        #
        # ==== Attributes
        #
        # * +title+ - Title of the task
        # * +block+ - Block for the task, will be provided with an instance of the spinner
        #
        # ==== Example Usage:
        #   spin_group = CLI::UI::SpinGroup.new
        #   spin_group.add('Title') { |spinner| sleep 1.0 }
        #   spin_group.wait
        #
        sig do
          params(
            title: String,
            final_glyph: T.proc.params(success: T::Boolean).returns(T.any(Glyph, String)),
            merged_output: T::Boolean,
            duplicate_output_to: IO,
            block: T.proc.params(task: Task).void,
          ).void
        end
        def add(
          title,
          final_glyph: DEFAULT_FINAL_GLYPH,
          merged_output: false,
          duplicate_output_to: File.new(File::NULL, 'w'),
          &block
        )
          @m.synchronize do
            @tasks << Task.new(
              title,
              final_glyph: final_glyph,
              merged_output: merged_output,
              duplicate_output_to: duplicate_output_to,
              work_queue: @work_queue,
              &block
            )
          end
        end

        sig { void }
        def stop
          # If we already own the mutex (called from within another synchronized block),
          # set stopped directly to avoid deadlock
          if @m.owned?
            return if @stopped

            @stopped = true
          else
            @m.synchronize do
              return if @stopped

              @stopped = true
            end
          end
          # Interrupt is thread-safe on its own, so we can call it outside the mutex
          @work_queue.interrupt
        end

        sig { returns(T::Boolean) }
        def stopped?
          if @m.owned?
            @stopped
          else
            @m.synchronize { @stopped }
          end
        end

        # Tells the group you're done adding tasks and to wait for all of them to finish
        #
        # ==== Options
        #
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout
        #
        # ==== Example Usage:
        #   spin_group = CLI::UI::SpinGroup.new
        #   spin_group.add('Title') { |spinner| sleep 1.0 }
        #   spin_group.wait
        #
        sig { params(to: IOLike).returns(T::Boolean) }
        def wait(to: $stdout)
          idx = 0

          consumed_lines = 0

          @work_queue.close if @internal_work_queue

          tasks_seen = @tasks.map { false }
          tasks_seen_done = @tasks.map { false }

          loop do
            break if stopped?

            done_count = 0

            width = CLI::UI::Terminal.width

            self.class.pause_mutex.synchronize do
              next if self.class.paused?

              @m.synchronize do
                CLI::UI.raw do
                  force_full_render = false

                  unless @puts_above.empty?
                    to.print(CLI::UI::ANSI.cursor_up(consumed_lines)) if CLI::UI.enable_cursor?
                    while (message = @puts_above.shift)
                      to.print(CLI::UI::ANSI.insert_lines(message.lines.count)) if CLI::UI.enable_cursor?
                      message.lines.each do |line|
                        to.print(CLI::UI::Frame.prefix + CLI::UI.fmt(line))
                      end
                      to.print("\n")
                    end
                    # we descend with newlines rather than ANSI.cursor_down as the inserted lines may've
                    # pushed the spinner off the front of the buffer, so we can't move back down below it
                    to.print("\n" * consumed_lines) if CLI::UI.enable_cursor?

                    force_full_render = true
                  end

                  @tasks.each.with_index do |task, int_index|
                    nat_index = int_index + 1
                    task_done = task.check
                    done_count += 1 if task_done

                    if CLI::UI.enable_cursor?
                      if nat_index > consumed_lines
                        to.print(task.render(idx, true, width: width) + "\n")
                        consumed_lines += 1
                      else
                        offset = consumed_lines - int_index
                        move_to = CLI::UI::ANSI.cursor_up(offset) + "\r"
                        move_from = "\r" + CLI::UI::ANSI.cursor_down(offset)

                        to.print(move_to + task.render(idx, idx.zero? || force_full_render, width: width) + move_from)
                      end
                    elsif !tasks_seen[int_index] || (task_done && !tasks_seen_done[int_index])
                      to.print(task.render(idx, true, width: width) + "\n")
                    end

                    tasks_seen[int_index] = true
                    tasks_seen_done[int_index] ||= task_done
                  end
                end
              end
            end

            break if done_count == @tasks.size

            idx = (idx + 1) % GLYPHS.size
            Spinner.index = idx
            sleep(PERIOD)
          end

          if @auto_debrief
            debrief(to: to)
          else
            all_succeeded?
          end
        rescue Interrupt
          @work_queue.interrupt
          debrief(to: to) if @interrupt_debrief
          stopped? ? false : raise
        end

        sig { params(message: String).void }
        def puts_above(message)
          @m.synchronize do
            @puts_above << message
          end
        end

        # Provide an alternative debriefing for failed tasks
        sig do
          params(
            block: T.proc.params(title: String, exception: T.nilable(Exception), out: String, err: String).void,
          ).void
        end
        def failure_debrief(&block)
          @failure_debrief = block
        end

        # Provide a debriefing for successful tasks
        sig do
          params(
            block: T.proc.params(title: String, out: String, err: String).void,
          ).void
        end
        def success_debrief(&block)
          @success_debrief = block
        end

        sig { returns(T::Boolean) }
        def all_succeeded?
          @m.synchronize do
            @tasks.all?(&:success)
          end
        end

        # Debriefs failed tasks is +auto_debrief+ is true
        #
        # ==== Options
        #
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout
        #
        sig { params(to: IOLike).returns(T::Boolean) }
        def debrief(to: $stdout)
          @m.synchronize do
            @tasks.each do |task|
              next unless task.done

              title = task.title
              out = task.stdout
              err = task.stderr

              if task.success
                next @success_debrief&.call(title, out, err)
              end

              # exception will not be set if the wait loop is stopped before the task is checked
              e = task.exception
              next @failure_debrief.call(title, e, out, err) if @failure_debrief

              CLI::UI::Frame.open('Task Failed: ' + title, color: :red, timing: Time.new - @start) do
                if e
                  to.puts("#{e.class}: #{e.message}")
                  to.puts("\tfrom #{e.backtrace.join("\n\tfrom ")}")
                end

                CLI::UI::Frame.divider('STDOUT')
                out = '(empty)' if out.nil? || out.strip.empty?
                to.puts(out)

                CLI::UI::Frame.divider('STDERR')
                err = '(empty)' if err.nil? || err.strip.empty?
                to.puts(err)
              end
            end
            @tasks.all?(&:success)
          end
        end
      end
    end
  end
end
