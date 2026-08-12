# typed: true
# frozen_string_literal: true

module CLI
  module UI
    # Truncater truncates a string to a provided printable width.
    module Truncater
      TRUNCATED = "\x1b[0m…"

      class << self
        #: (String text, Integer printing_width) -> String
        def call(text, printing_width)
          # Fast path. Only sound for ASCII, where no character is wider
          # than a column: an emoji string can occupy up to twice as many
          # columns as it has characters.
          return text if text.ascii_only? && text.size <= printing_width

          width = 0 #: Integer
          truncated = false #: bool
          open_hyperlink = false #: bool
          # Preserve the caller's encoding. Printer can deliberately pass
          # ASCII-compatible strings in encodings other than UTF-8, and an
          # empty UTF-8 buffer becomes incompatible after binary text has
          # been appended to it.
          prefix = String.new(encoding: text.encoding)

          ANSI.each_token(text) do |kind, token|
            case kind
            when :sequence
              # Sequences occupy no columns. Any that fall past the cut are
              # dropped: TRUNCATED resets SGR state itself, and an open
              # hyperlink gets closed below.
              next if truncated

              prefix << token
              if (match = ANSI::HYPERLINK.match(token))
                open_hyperlink = !match[:uri].to_s.empty?
              end
            when :text
              token.grapheme_clusters.each do |cluster|
                # A line break is zero columns to printing_width, but a
                # truncated string must stay one line: count it as a column
                # so the cut lands before it, never absorbing it silently.
                # Other zero-width clusters remain zero-width.
                cluster_width = case cluster
                when "\n", "\r", "\r\n"
                  1
                else
                  ANSI.grapheme_width(cluster)
                end
                width += cluster_width
                # We cut before the cluster that reaches printing_width,
                # leaving one column for TRUNCATED's ellipsis, but keep
                # measuring: if the rest of the string turns out not to
                # exceed printing_width after all, no cut is needed.
                truncated ||= width >= printing_width
                prefix << cluster unless truncated
              end
            end
          end

          # Without the `width <= printing_width` check, we truncate
          # "foo\x1b[0m" for a width of 3, but it should not be truncated.
          # It's specifically for the case where we decided "Yes, this is the
          # point at which we'd have to add a truncation!" but it's actually
          # the end of the string.
          return text if !truncated || width <= printing_width

          prefix << ANSI::HYPERLINK_END.encode(text.encoding) if open_hyperlink
          prefix << truncation_marker(text.encoding)
        end

        private

        # Keep the reset and marker in the input encoding. Some
        # ASCII-compatible encodings cannot represent U+2026; a one-column
        # question mark preserves the width contract in that case.
        #
        #: (Encoding encoding) -> String
        def truncation_marker(encoding)
          TRUNCATED.encode(encoding, invalid: :replace, undef: :replace, replace: '?')
        end
      end
    end
  end
end
