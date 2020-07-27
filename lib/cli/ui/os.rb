module CLI
  module UI
    module OS
      # Determines which OS is currently running the UI, to make it easier to
      # adapt its behaviour to the features of the OS.
      def self.current
        return @current_os unless @current_os.nil?

        @current_os = Mac if /darwin/.match(RUBY_PLATFORM)
        @current_os = Linux if /linux/.match(RUBY_PLATFORM)
        @current_os = Windows if /mingw32/.match(RUBY_PLATFORM)

        raise "Could not determine OS from platform #{RUBY_PLATFORM}" if @current_os.nil?
        @current_os
      end

      class Mac
        class << self
          def supports_emoji?
            true
          end

          def supports_color_prompt?
            true
          end

          def supports_arrow_keys?
            true
          end

          def shift_cursor_on_line_reset?
            false
          end
        end
      end

      class Linux < Mac
      end

      class Windows
        class << self
          def supports_emoji?
            false
          end

          def supports_color_prompt?
            false
          end

          def supports_arrow_keys?
            false
          end

          def shift_cursor_on_line_reset?
            true
          end
        end
      end
    end
  end
end
