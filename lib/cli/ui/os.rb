# typed: true

require 'rbconfig'

module CLI
  module UI
    class OS
      extend T::Sig

      sig { params(emoji: T::Boolean, color_prompt: T::Boolean, arrow_keys: T::Boolean, shift_cursor: T::Boolean).void }
      def initialize(emoji: true, color_prompt: true, arrow_keys: true, shift_cursor: false)
        @emoji = emoji
        @color_prompt = color_prompt
        @arrow_keys = arrow_keys
        @shift_cursor = shift_cursor
      end

      sig { returns(T::Boolean) }
      def use_emoji?
        @emoji
      end

      sig { returns(T::Boolean) }
      def use_color_prompt?
        @color_prompt
      end

      sig { returns(T::Boolean) }
      def suggest_arrow_keys?
        @arrow_keys
      end

      sig { returns(T::Boolean) }
      def shift_cursor_back_on_horizontal_absolute?
        @shift_cursor
      end

      class << self
        extend T::Sig

        sig { returns(OS) }
        def current
          @current_os ||= case RbConfig::CONFIG['host_os']
          when /darwin/
            MAC
          when /linux/
            LINUX
          else
            if RUBY_PLATFORM !~ /cygwin/ && ENV['OS'] == 'Windows_NT'
              WINDOWS
            else
              raise "Could not determine OS from host_os #{RbConfig::CONFIG["host_os"]}"
            end
          end
        end
      end

      MAC = OS.new
      LINUX = OS.new
      WINDOWS = OS.new(emoji: false, color_prompt: false, arrow_keys: false, shift_cursor: true)
    end
  end
end
