# typed: true
# frozen_string_literal: true

require 'rbconfig'

module CLI
  module UI
    class OS
      #: (?emoji: bool, ?color_prompt: bool, ?arrow_keys: bool, ?shift_cursor: bool) -> void
      def initialize(emoji: true, color_prompt: true, arrow_keys: true, shift_cursor: false)
        @emoji = emoji
        @color_prompt = color_prompt
        @arrow_keys = arrow_keys
        @shift_cursor = shift_cursor
      end

      #: -> bool
      def use_emoji?
        @emoji
      end

      #: -> bool
      def use_color_prompt?
        @color_prompt
      end

      #: -> bool
      def suggest_arrow_keys?
        @arrow_keys
      end

      #: -> bool
      def shift_cursor_back_on_horizontal_absolute?
        @shift_cursor
      end

      class << self
        #: -> OS
        def current
          @current_os ||= case RbConfig::CONFIG['host_os']
          when /darwin/
            MAC
          when /linux/
            LINUX
          when /freebsd/
            FREEBSD
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
      FREEBSD = OS.new
      WINDOWS = OS.new(emoji: false, color_prompt: false, arrow_keys: false, shift_cursor: true)
    end
  end
end
