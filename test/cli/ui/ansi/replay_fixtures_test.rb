# frozen_string_literal: true

require 'test_helper'
require 'cli/ui/ansi'

module CLI
  module UI
    module ANSI
      # Real cli-ui captures paired with the text xterm.js settles on. The
      # expectations come from xterm.js rather than from this implementation,
      # so they catch a replay that is self-consistently wrong. See
      # test/fixtures/replay/README.md.
      class ReplayFixturesTest < Minitest::Test
        FIXTURES = File.expand_path('../../../fixtures/replay', __dir__)
        CAPTURES = Dir.glob(File.join(FIXTURES, '*.raw')).sort.freeze

        CAPTURES.each do |capture|
          name = File.basename(capture, '.raw')

          define_method(:"test_#{name}_replays_to_xterm_js_output") do
            expected = File.read(File.join(FIXTURES, "#{name}.expected"), encoding: Encoding::UTF_8)

            assert_equal(expected, ANSI.replay(File.binread(capture)))
          end
        end

        # A fixture only earns its place by holding terminal history that
        # replay meaningfully collapses; a regenerated capture that lost it
        # would still pass the assertions above.
        def test_every_capture_contains_collapsible_terminal_history
          refute_empty(CAPTURES)

          CAPTURES.each do |capture|
            raw = File.binread(capture)

            assert_operator(
              ANSI.replay(raw).bytesize,
              :<,
              ANSI.strip_codes(raw.dup.force_encoding(Encoding::UTF_8)).bytesize,
              "#{File.basename(capture)} holds nothing for replay to collapse",
            )
          end
        end
      end
    end
  end
end
