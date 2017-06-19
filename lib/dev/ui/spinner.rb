require 'dev/ui'

module Dev
  module UI
    module Spinner
      PERIOD = 0.1 # seconds

      begin
        runes = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        colors = [Dev::UI::Color::CYAN.code] * 5 + [Dev::UI::Color::MAGENTA.code] * 5
        raise unless runes.size == colors.size
        GLYPHS = colors.zip(runes).map(&:join)
      end

      def self.spin(title, &block)
        sg = SpinGroup.new
        sg.add(title, &block)
        sg.wait
      end

      class SpinGroup
        def initialize
          @m = Mutex.new
          @consumed_lines = 0
          @tasks = []
        end

        class Task
          attr_reader :title, :exception, :success, :stdout, :stderr

          def initialize(title, &block)
            @title = title
            @thread = Thread.new do
              cap = Dev::UI::StdoutRouter::Capture.new(self, with_frame_inset: false, &block)
              begin
                cap.run
              ensure
                @stdout = cap.stdout
                @stderr = cap.stderr
              end
            end

            @force_full_render = false
            @done      = false
            @exception = nil
            @success   = false
          end

          def check
            return true if @done
            return false if @thread.alive?

            @done = true
            begin
              status = @thread.join.status
              @success = (status == false)
            rescue => exc
              @exception = exc
              @success = false
            end

            @done
          end

          def render(index, force = true)
            return full_render(index) if force || @force_full_render
            partial_render(index)
          ensure
            @force_full_render = false
          end

          def update_title(new_title)
            @title = new_title
            @force_full_render = true
          end

          private

          def full_render(index)
            inset + glyph(index) + Dev::UI::Color::RESET.code + ' ' + Dev::UI.resolve_text(title) + "\e[K"
          end

          def partial_render(index)
            Dev::UI::ANSI.cursor_forward(inset_width) + glyph(index) + Dev::UI::Color::RESET.code
          end

          def glyph(index)
            if @done
              @success ? Dev::UI::Glyph::CHECK.to_s : Dev::UI::Glyph::X.to_s
            else
              GLYPHS[index]
            end
          end

          def inset
            @inset ||= Dev::UI::Frame.prefix
          end

          def inset_width
            @inset_width ||= Dev::UI::ANSI.printing_width(inset)
          end
        end

        def add(title, &block)
          @m.synchronize do
            @tasks << Task.new(title, &block)
          end
        end

        def wait
          idx = 0

          loop do
            all_done = true

            @m.synchronize do
              Dev::UI.raw do
                @tasks.each.with_index do |task, int_index|
                  nat_index = int_index + 1
                  task_done = task.check
                  all_done = false unless task_done

                  if nat_index > @consumed_lines
                    print(task.render(idx, true) + "\n")
                    @consumed_lines += 1
                  else
                    offset = @consumed_lines - int_index
                    move_to   = Dev::UI::ANSI.cursor_up(offset) + "\r"
                    move_from = "\r" + Dev::UI::ANSI.cursor_down(offset)

                    print(move_to + task.render(idx, idx.zero?) + move_from)
                  end
                end
              end
            end

            break if all_done

            idx = (idx + 1) % GLYPHS.size
            sleep(PERIOD)
          end

          debrief
        end

        def debrief
          @m.synchronize do
            @tasks.each do |task|
              next if task.success

              e = task.exception
              out = task.stdout
              err = task.stderr

              Dev::UI::Frame.open('Task Failed: ' + task.title, color: :red) do
                if e
                  puts"#{e.class}: #{e.message}"
                  puts "\tfrom #{e.backtrace.join("\n\tfrom ")}"
                end

                Dev::UI::Frame.divider('STDOUT')
                out = "(empty)" if out.nil? || out.strip.empty?
                puts out

                Dev::UI::Frame.divider('STDERR')
                err = "(empty)" if err.nil? || err.strip.empty?
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
