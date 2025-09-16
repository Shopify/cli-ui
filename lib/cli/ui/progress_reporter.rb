# typed: true
# frozen_string_literal: true

module CLI
  module UI
    # Handles terminal progress bar reporting using ConEmu OSC 9;4 sequences
    # Supports:
    # - Numerical progress (0-100%)
    # - Indeterminate/pulsing progress
    # - Success/error states
    # - Paused state
    module ProgressReporter
      extend T::Sig

      # Progress reporter instance that manages the lifecycle of progress reporting
      class Reporter
        extend T::Sig

        # OSC (Operating System Command) escape sequences
        OSC = "\e]"
        ST = "\a" # String Terminator (BEL)

        # Progress states
        REMOVE = 0
        SET_PROGRESS = 1
        ERROR = 2
        INDETERMINATE = 3
        PAUSED = 4

        sig { params(mode: Symbol, to: IOLike, parent: T.nilable(Reporter), delay_start: T::Boolean).void }
        def initialize(mode, to = $stdout, parent: nil, delay_start: false)
          @mode = mode
          @to = to
          @parent = parent
          @children = []
          @active = ProgressReporter.supports_progress? && @parent.nil?

          # Register with parent if nested
          @parent&.add_child(self)

          return unless @active
          return if delay_start # Don't emit initial OSC if delayed

          case mode
          when :indeterminate
            set_indeterminate
          when :progress
            set_progress(0)
          else
            raise ArgumentError, "Unknown progress mode: #{mode}"
          end
        end

        sig { params(child: Reporter).void }
        def add_child(child)
          @children << child
        end

        sig { params(child: Reporter).void }
        def remove_child(child)
          @children.delete(child)
        end

        sig { returns(T::Boolean) }
        def has_active_children?
          @children.any?
        end

        sig { params(percentage: Integer).void }
        def set_progress(percentage) # rubocop:disable Naming/AccessorMethodName
          # Don't emit progress if we have active children (they own the progress)
          return if has_active_children?
          return unless @active

          @mode = :progress # Update mode when switching to progress
          percentage = percentage.clamp(0, 100)
          @to.print("#{OSC}9;4;#{SET_PROGRESS};#{percentage}#{ST}")
        end

        sig { void }
        def set_indeterminate
          # Don't emit progress if we have active children
          return if has_active_children?
          return unless @active

          @mode = :indeterminate # Update mode when switching to indeterminate
          @to.print("#{OSC}9;4;#{INDETERMINATE};#{ST}")
        end

        # Force progress mode even if there are children - used by SpinGroup
        # when a task needs to show deterministic progress
        sig { params(percentage: Integer).void }
        def force_set_progress(percentage)
          return unless @active

          @mode = :progress
          percentage = percentage.clamp(0, 100)
          @to.print("#{OSC}9;4;#{SET_PROGRESS};#{percentage}#{ST}")
        end

        # Force indeterminate mode even if there are children
        sig { void }
        def force_set_indeterminate
          return unless @active

          @mode = :indeterminate
          @to.print("#{OSC}9;4;#{INDETERMINATE};#{ST}")
        end

        sig { void }
        def set_error
          # Error state can be set even with children
          return unless @active

          @to.print("#{OSC}9;4;#{ERROR};#{ST}")
        end

        sig { params(percentage: T.nilable(Integer)).void }
        def set_paused(percentage = nil)
          return if has_active_children?
          return unless @active

          if percentage
            percentage = percentage.clamp(0, 100)
            @to.print("#{OSC}9;4;#{PAUSED};#{percentage}#{ST}")
          else
            @to.print("#{OSC}9;4;#{PAUSED};#{ST}")
          end
        end

        sig { void }
        def clear
          # Only clear if we're the root reporter and have no active children
          return unless @active
          return if has_active_children?

          @to.print("#{OSC}9;4;#{REMOVE};#{ST}")
        end

        sig { void }
        def cleanup
          # Remove self from parent's children list
          @parent&.remove_child(self)

          # If parent exists and has no more children, restore its progress state
          if @parent && !@parent.has_active_children?
            case @parent.instance_variable_get(:@mode)
            when :indeterminate
              @parent.set_indeterminate
            when :progress
              # Parent progress bar should maintain its last state
              # The parent will handle re-emitting its progress on next tick
            end
          elsif !@parent
            # We're the root, clear progress
            clear
          end
        end
      end

      class << self
        extend T::Sig

        # Thread-local storage for the current reporter stack
        sig { returns(T::Array[Reporter]) }
        def reporter_stack
          Thread.current[:progress_reporter_stack] ||= []
        end

        sig { returns(T.nilable(Reporter)) }
        def current_reporter
          reporter_stack.last
        end

        # Block-based API that ensures progress is cleared
        sig do
          type_parameters(:T)
            .params(
              mode: Symbol,
              to: IOLike,
              delay_start: T::Boolean,
              block: T.proc.params(reporter: Reporter).returns(T.type_parameter(:T)),
            )
            .returns(T.type_parameter(:T))
        end
        def with_progress(mode: :indeterminate, to: $stdout, delay_start: false, &block)
          parent = current_reporter
          reporter = Reporter.new(mode, to, parent: parent, delay_start: delay_start)

          reporter_stack.push(reporter)
          yield(reporter)
        ensure
          reporter_stack.pop
          reporter&.cleanup
        end

        sig { returns(T::Boolean) }
        def supports_progress?
          # Check if terminal supports ConEmu OSC sequences
          # This is supported by:
          # - ConEmu on Windows
          # - Windows Terminal
          # - Ghostty
          # - Various terminals on Linux (with OSC 9;4 support)

          # Check common environment variables that indicate support
          return true if ENV['ConEmuPID']
          return true if ENV['WT_SESSION'] # Windows Terminal
          return true if ENV['GHOSTTY_RESOURCES_DIR'] # Ghostty

          # Check TERM_PROGRAM for known supporting terminals
          term_program = ENV['TERM_PROGRAM']
          return true if term_program == 'ghostty'

          # For now, we'll be conservative and only enable for known terminals
          # Users can force-enable with an environment variable
          return true if ENV['CLI_UI_ENABLE_PROGRESS'] == '1'

          false
        end
      end
    end
  end
end
