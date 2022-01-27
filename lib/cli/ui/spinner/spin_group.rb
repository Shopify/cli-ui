# typed: true
module CLI
  module UI
    module Spinner
      class SpinGroup
        extend T::Sig

        # Initializes a new spin group
        # This lets you add +Task+ objects to the group to multi-thread work
        #
        # ==== Options
        #
        # * +:auto_debrief+ - Automatically debrief exceptions? Default to true
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
          @consumed_lines = 0
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
          sig { params(title: String, block: T.proc.params(task: Task).returns(T.untyped)).void }
          def initialize(title, &block)
            @title = title
            @always_full_render = title =~ Formatter::SCAN_WIDGET
            @thread = Thread.new do
              cap = CLI::UI::StdoutRouter::Capture.new(with_frame_inset: false) { block.call(self) }
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
              if force || @always_full_render || @force_full_render
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
            prefix = inset +
              glyph(index) +
              CLI::UI::Color::RESET.code +
              ' '

            truncation_width = terminal_width - CLI::UI::ANSI.printing_width(prefix)

            prefix +
              CLI::UI.resolve_text(title, truncate_to: truncation_width) +
              "\e[K"
          end

          sig { params(index: Integer).returns(String) }
          def partial_render(index)
            CLI::UI::ANSI.cursor_forward(inset_width) + glyph(index) + CLI::UI::Color::RESET.code
          end

          sig { params(index: Integer).returns(String) }
          def glyph(index)
            if @done
              @success ? CLI::UI::Glyph::CHECK.to_s : CLI::UI::Glyph::X.to_s
            else
              GLYPHS[index]
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
        sig { params(title: String, block: T.proc.params(task: Task).void).void }
        def add(title, &block)
          @m.synchronize do
            @tasks << Task.new(title, &block)
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

          loop do
            all_done = T.let(true, T::Boolean)

            width = CLI::UI::Terminal.width

            @m.synchronize do
              CLI::UI.raw do
                @tasks.each.with_index do |task, int_index|
                  nat_index = int_index + 1
                  task_done = task.check
                  all_done = false unless task_done

                  if nat_index > @consumed_lines
                    print(task.render(idx, true, width: width) + "\n")
                    @consumed_lines += 1
                  else
                    offset = @consumed_lines - int_index
                    move_to = CLI::UI::ANSI.cursor_up(offset) + "\r"
                    move_from = "\r" + CLI::UI::ANSI.cursor_down(offset)

                    print(move_to + task.render(idx, idx.zero?, width: width) + move_from)
                  end
                end
              end
            end

            break if all_done

            idx = (idx + 1) % GLYPHS.size
            Spinner.index = idx
            sleep(PERIOD)
          end

          if @auto_debrief
            debrief
          else
            @m.synchronize do
              @tasks.all?(&:success)
            end
          end
        end

        # Debriefs failed tasks is +auto_debrief+ is true
        #
        sig { returns(T::Boolean) }
        def debrief
          @m.synchronize do
            @tasks.each do |task|
              next if task.success

              e = task.exception
              out = task.stdout
              err = task.stderr

              CLI::UI::Frame.open('Task Failed: ' + task.title, color: :red, timing: Time.new - @start) do
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
