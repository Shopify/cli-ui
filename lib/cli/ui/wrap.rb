# coding: utf-8
# typed: true
# frozen_string_literal: true

module CLI
  module UI
    class Wrap
      # SGR parameters are separated by ; or, in the underspecified-but-real
      # colon form of extended colors (\x1b[38:2::255:0:0m), by :.
      SGR = /\A\x1b\[[\d;:]*m\z/

      #: (String input) -> void
      def initialize(input)
        @input = input
      end

      #: (?Integer total_width) -> String
      def wrap(total_width = Terminal.width)
        max_width = total_width - Frame.prefix_width
        width = 0 #: Integer
        final = +''
        # SGR codes in effect, resent after each line break so that frame
        # coloring doesn't clobber them mid-paragraph. An open hyperlink
        # likewise gets closed at the break and reopened after it, keeping
        # the frame gutter outside the link.
        sgr_state = {} #: Hash[String, String]
        open_hyperlink = nil #: String?
        break_line = -> do
          final << ANSI::HYPERLINK_END if open_hyperlink
          final << "\n" << active_sgr(sgr_state) << open_hyperlink.to_s
          width = 0
        end

        ANSI.each_token(@input) do |kind, token|
          if kind == :sequence
            case token
            when SGR
              track_sgr(token, sgr_state)
            when ANSI::HYPERLINK
              match = ANSI::HYPERLINK.match(token) #: as !nil
              open_hyperlink = match[:uri].to_s.empty? ? nil : token
            end
            final << token
            next
          end

          # Split the text run so each whitespace character is its own
          # token: lines break at whitespace, and a space that would sit in
          # the last column becomes the break itself.
          token.split(/(?=\s)|(?<=\s)/).each do |chunk|
            if chunk == "\n"
              break_line.call
              next
            end

            chunk_width = ANSI.printing_width(chunk)
            if width + chunk_width <= max_width
              final << chunk
              width += chunk_width
            elsif chunk.match?(/\A\s\z/)
              break_line.call
            else
              break_line.call
              final << chunk
              width = chunk_width
            end
          end
        end
        final
      end

      private

      # Reconstructs the active SGR commands as one deduplicated sequence.
      #
      #: (Hash[String, String] state) -> String
      def active_sgr(state)
        state.empty? ? '' : "\e[#{state.values.join(";")}m"
      end

      # Keeps only the most recent command for each SGR parameter, with shared
      # slots for the color commands whose payloads can vary. Deleting before
      # reinserting preserves the order of each command's last occurrence, so
      # an on/off/on sequence replays in the same effective order without
      # retaining the full formatting history.
      #
      # A reset can hide mid-list: parameters reset at a 0 or an empty entry
      # (\e[0;33m, \e[;1m), while zeros inside a colon-form parameter are
      # subparameters rather than commands.
      #
      #: (String token, Hash[String, String] state) -> void
      def track_sgr(token, state)
        params = token[2...-1].to_s.split(';', -1)
        params = ['0'] if params.empty?
        index = 0
        while index < params.length
          param = params.fetch(index)
          param = '0' if param.empty?
          code = param.split(':', 2).first.to_i
          command = param
          consumed = 0

          if code == 38 || code == 48 || code == 58
            command, consumed = color_command(params, index)
          end
          remember_sgr(state, code, command) if command
          index += consumed + 1
        end
      end

      # Semicolon-form extended colors consume their following parameters;
      # colon-form colors are already one parameter and need no grouping.
      #
      #: (Array[String] params, Integer index) -> [String?, Integer]
      def color_command(params, index)
        param = params.fetch(index)
        return [param, 0] if param.include?(':')

        case params[index + 1]
        when '5'
          return [nil, params.length - index - 1] if params[index + 2].nil?

          [params[index, 3].to_a.join(';'), 2]
        when '2'
          length = params[index + 2].to_s.empty? ? 6 : 5
          return [nil, params.length - index - 1] if params.length < index + length

          [params[index, length].to_a.join(';'), length - 1]
        else
          [nil, 0]
        end
      end

      #: (Hash[String, String] state, Integer code, String command) -> void
      def remember_sgr(state, code, command)
        if code.zero?
          state.clear
          return
        end

        key = sgr_key(code)
        state.delete(key)
        state[key] = command
      end

      #: (Integer code) -> String
      def sgr_key(code)
        case code
        when 30..39, 90..97
          'foreground'
        when 40..49, 100..107
          'background'
        when 58, 59
          'underline_color'
        else
          code.to_s
        end
      end
    end
  end
end
