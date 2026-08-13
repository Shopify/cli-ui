# typed: true
# frozen_string_literal: true

module CLI
  module UI
    # Truncater truncates a string to a provided printable width.
    module Truncater
      PARSE_ROOT    = :root
      PARSE_ANSI    = :ansi
      PARSE_ESC     = :esc
      PARSE_ZWJ     = :zwj
      PARSE_OSC     = :osc
      PARSE_OSC_END = :osc_end

      ESC                  = 0x1b
      LEFT_SQUARE_BRACKET  = 0x5b
      RIGHT_SQUARE_BRACKET = 0x5d # ]
      BACKSLASH            = 0x5c # \
      BEL                  = 0x07
      ZWJ                  = 0x200d # emojipedia.org/emoji-zwj-sequences
      SEMICOLON            = 0x3b

      # EMOJI_RANGE in particular is super inaccurate. This is best-effort.
      # If you need this to be more accurate, we'll almost certainly accept a
      # PR improving it.
      EMOJI_RANGE    = 0x1f300..0x1f5ff
      NUMERIC_RANGE  = 0x30..0x39
      LC_ALPHA_RANGE = 0x40..0x5a
      UC_ALPHA_RANGE = 0x60..0x71

      TRUNCATED = "\x1b[0m…"
      # OSC 8 close (empty URI). Both BEL and ST terminate OSC; we emit ST here
      # to match CLI::UI.link / ANSI hyperlink endings.
      HYPERLINK_END = "\x1b]8;;\x1b\\"

      class << self
        #: (String text, Integer printing_width) -> String
        def call(text, printing_width)
          return text if text.size <= printing_width

          width                   = 0
          mode                    = PARSE_ROOT
          truncation_index        = nil #: Integer?
          open_hyperlink          = false
          open_hyperlink_at_cut   = false
          osc_payload_start       = nil #: Integer?

          codepoints = text.codepoints
          codepoints.each.with_index do |cp, index|
            case mode
            when PARSE_ROOT
              case cp
              when ESC # non-printable, followed by some more non-printables.
                mode = PARSE_ESC
              when ZWJ # non-printable, followed by another non-printable.
                mode = PARSE_ZWJ
              else
                width += width(cp)
                if width >= printing_width
                  unless truncation_index
                    truncation_index = index
                    open_hyperlink_at_cut = open_hyperlink
                  end
                  # it looks like we could break here but we still want the
                  # width calculation for the rest of the characters.
                end
              end
            when PARSE_ESC
              mode = case cp
              when LEFT_SQUARE_BRACKET
                PARSE_ANSI
              when RIGHT_SQUARE_BRACKET
                osc_payload_start = index + 1
                PARSE_OSC
              else
                PARSE_ROOT
              end
            when PARSE_ANSI
              # ANSI escape codes preeeetty much have the format of:
              # \x1b[0-9;]+[A-Za-z]
              case cp
              when NUMERIC_RANGE, SEMICOLON
              when LC_ALPHA_RANGE, UC_ALPHA_RANGE
                mode = PARSE_ROOT
              else
                # unexpected. let's just go back to the root state I guess?
                mode = PARSE_ROOT
              end
            when PARSE_OSC
              # BEL and ST (ESC \) both terminate OSC; see ANSI::OSC_SEQUENCE.
              case cp
              when BEL
                state = osc8_link_state(codepoints, osc_payload_start, index)
                open_hyperlink = state unless state.nil?
                osc_payload_start = nil
                mode = PARSE_ROOT
              when ESC
                mode = PARSE_OSC_END
              end
            when PARSE_OSC_END
              if cp == BACKSLASH
                # ST is ESC \; payload ends before the ESC.
                state = osc8_link_state(codepoints, osc_payload_start, index - 1)
                open_hyperlink = state unless state.nil?
                osc_payload_start = nil
                mode = PARSE_ROOT
              else
                # Not a String Terminator — keep consuming as OSC payload.
                mode = PARSE_OSC
              end
            when PARSE_ZWJ
              # consume any character and consider it as having no width
              # width(x+ZWJ+y) = width(x).
              mode = PARSE_ROOT
            end
          end

          # Without the `width <= printing_width` check, we truncate
          # "foo\x1b[0m" for a width of 3, but it should not be truncated.
          # It's specifically for the case where we decided "Yes, this is the
          # point at which we'd have to add a truncation!" but it's actually
          # the end of the string.
          return text if !truncation_index || width <= printing_width

          slice = codepoints[0...truncation_index] #: as !nil
          truncated = slice.pack('U*')
          truncated += HYPERLINK_END if open_hyperlink_at_cut
          truncated + TRUNCATED
        end

        private

        #: (Array[Integer] codepoints, Integer? start, Integer end_exclusive) -> bool?
        def osc8_link_state(codepoints, start, end_exclusive)
          return nil if start.nil? || end_exclusive <= start

          payload = codepoints[start...end_exclusive].pack('U*')
          return nil unless payload.start_with?('8;')

          # OSC 8: 8;params;URI — nonempty URI opens a link; empty closes it.
          # Non-OSC8 sequences return nil so Truncater does not clear open-link state.
          _params, uri = payload.delete_prefix('8;').split(';', 2)
          !uri.to_s.empty?
        end

        #: (Integer printable_codepoint) -> Integer
        def width(printable_codepoint)
          case printable_codepoint
          when EMOJI_RANGE
            2
          else
            1
          end
        end
      end
    end
  end
end
