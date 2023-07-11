# typed: true

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
        sig { params(auto_debrief: T::Boolean).void }
        def initialize(auto_debrief: true)
          @m = Mutex.new
          @tasks = []
          @auto_debrief = auto_debrief
          @start = Time.new
          if block_given?
            yield self
            wait
          end
        end

        class Task
          extend T::Sig

          sig { returns(String) }
          attr_reader :title, :stdout, :stderr

          sig { returns(T::Boolean) }
          attr_reader :success

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
              block: T.proc.params(task: Task).returns(T.untyped),
            ).void
          end
          def initialize(title, final_glyph:, merged_output:, duplicate_output_to:, &block)
            @title = title
            @final_glyph = final_glyph
            @always_full_render = title =~ Formatter::SCAN_WIDGET
            @thread = Thread.new do
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
            @success   = false
          end

          # Checks if a task is finished
          #
          sig { returns(T::Boolean) }
          def check
            return true if @done
            return false if @thread.alive?

            @done = true
            begin
              status = @thread.join.status
              @success = (status == false)
              @success = false if @thread.value == TASK_FAILED
            rescue => exc
              @exception = exc
              @success = false
            end

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

          sig { void }
          def interrupt
            @thread.raise(Interrupt)
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
              CLI::UI.enable_color? ? GLYPHS[index] : RUNES[index]
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
              &block
            )
          end
        end

        # Tells the group you're done adding tasks and to wait for all of them to finish
        #
        # ==== Example Usage:
        #   spin_group = CLI::UI::SpinGroup.new
        #   spin_group.add('Title') { |spinner| sleep 1.0 }
        #   spin_group.wait
        #
        sig { returns(T::Boolean) }
        def wait
          idx = 0

          consumed_lines = 0

          tasks_seen = @tasks.map { false }
          tasks_seen_done = @tasks.map { false }

          loop do
            done_count = 0

            width = CLI::UI::Terminal.width

            self.class.pause_mutex.synchronize do
              next if self.class.paused?

              @m.synchronize do
                CLI::UI.raw do
                  @tasks.each.with_index do |task, int_index|
                    nat_index = int_index + 1
                    task_done = task.check
                    done_count += 1 if task_done

                    if CLI::UI.enable_cursor?
                      if nat_index > consumed_lines
                        print(task.render(idx, true, width: width) + "\n")
                        consumed_lines += 1
                      else
                        offset = consumed_lines - int_index
                        move_to = CLI::UI::ANSI.cursor_up(offset) + "\r"
                        move_from = "\r" + CLI::UI::ANSI.cursor_down(offset)

                        print(move_to + task.render(idx, idx.zero?, width: width) + move_from)
                      end
                    elsif !tasks_seen[int_index] || (task_done && !tasks_seen_done[int_index])
                      print(task.render(idx, true, width: width) + "\n")
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
            debrief
          else
            all_succeeded?
          end
        rescue Interrupt
          @tasks.each(&:interrupt)
          raise
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
        sig { returns(T::Boolean) }
        def debrief
          @m.synchronize do
            @tasks.each do |task|
              title = task.title
              out = task.stdout
              err = task.stderr

              if task.success
                next @success_debrief&.call(title, out, err)
              end

              e = task.exception
              next @failure_debrief.call(title, e, out, err) if @failure_debrief

              CLI::UI::Frame.open('Task Failed: ' + title, color: :red, timing: Time.new - @start) do
                if e
                  puts "#{e.class}: #{e.message}"
                  puts "\tfrom #{e.backtrace.join("\n\tfrom ")}"
                end

                CLI::UI::Frame.divider('STDOUT')
                out = '(empty)' if out.nil? || out.strip.empty?
                puts out

                CLI::UI::Frame.divider('STDERR')
                err = '(empty)' if err.nil? || err.strip.empty?
                puts err
              end
            end
            @tasks.all?(&:success)
          end
        end
      end
    end
  end
end
