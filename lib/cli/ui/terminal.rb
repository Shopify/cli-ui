require 'cli/ui'
require 'fiddle'

module CLI
  module UI
    module Terminal
      # Useful references:
      #
      # List of capability names:
      #   https://www.freebsd.org/cgi/man.cgi?query=terminfo&sektion=5
      # Xterm terminfo settings:
      #   https://invisible-island.net/xterm/terminfo.html

      def self.width
        TermInfo.tigetnum('cols') || 80
      end

      def self.height
        TermInfo.tigetnum('lines') || 24
      end

      def self.previous_line
        cursor_up + cursor_horizontal_absolute(1)
      end

      def self.next_line
        cursor_down + cursor_horizontal_absolute(1)
      end

      def self.cursor_right(n = 1)
        return '' if n.zero?
        n == 1 ? fmt('cuf1') : fmt('cuf', n)
      end

      def self.cursor_left(n = 1)
        return '' if n.zero?
        n == 1 ? fmt('cub1') : fmt('cub', n)
      end

      def self.cursor_up(n = 1)
        return '' if n.zero?
        n == 1 ? fmt('cuu1') : fmt('cuu', n)
      end

      def self.cursor_down(n = 1)
        return '' if n.zero?
        n == 1 ? fmt('cud1') : fmt('cud', n)
      end

      def self.cursor_horizontal_absolute(n)
        fmt('hpa', n)
      end

      def self.cursor_vertical_absolute(n)
        fmt('vpa', n)
      end

      def self.clear_to_end_of_line
        fmt('el')
      end

      def self.show_cursor
        fmt('cnorm')
      end

      def self.hide_cursor
        fmt('civis')
      end

      def self.fg_color(n)
        fmt('setaf', n)
      end

      def self.bg_color(n)
        fmt('setab', n)
      end

      def self.italics_on
        fmt('sitm')
      end

      def self.italics_off
        fmt('ritm')
      end

      def self.underline_on
        fmt('smul')
      end

      def self.underline_off
        fmt('rmul')
      end

      def self.bold_on
        fmt('bold')
      end

      def self.exit_attribute_mode
        fmt('sgr0')
      end

      def self.save_cursor
        fmt('sc')
      end

      def self.restore_cursor
        fmt('rc')
      end

      def self.fmt(capname, *args)
        cap = TermInfo.tigetstr(capname)
        return "" unless cap
        return cap if args.empty?
        TermInfo.tparm(cap, *args)
      end
      private_class_method :fmt

      module TermInfo
        TERM = 'TERM'.freeze
        DEFAULT_TERM = 'xterm'.freeze
        STDOUT_FD = STDOUT.to_i

        class << self
          def tigetstr(str, term: termvar)
            setupterm_once(term)
            ret = TIGETSTR.call(str)
            ret.to_i == -1 ? nil : ret.to_s
          end

          def tigetnum(str, term: termvar)
            setupterm_once(term)
            ret = TIGETNUM.call(str)
            ret.to_i == -1 ? nil : ret
          end

          def tparm(str, *args)
            # setupterm_once(term) probably not necessary
            ret = TPARM[args.size].call(str, *args)
            ret.null? ? "" : ret.to_s
          end

          private

          def setupterm_once(term)
            return if @active == term
            SETUPTERM.call(term, STDOUT_FD, 0)
            @active = term
          end

          def termvar
            ENV.fetch(TERM, DEFAULT_TERM)
          end
        end

        # TODO: manage libncurses dependency on Linux
        LIBTERMCAP = Fiddle.dlopen('/usr/lib/libtermcap.dylib')
        private_constant :LIBTERMCAP

        TIGETFLAG = Fiddle::Function.new(
          LIBTERMCAP['tigetflag'],
          [Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT
        )

        TIGETNUM = Fiddle::Function.new(
          LIBTERMCAP['tigetnum'],
          [Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_INT
        )

        TPARM = (0..10).map do |n|
          Fiddle::Function.new(
            LIBTERMCAP['tparm'],
            [Fiddle::TYPE_VOIDP] * (n + 1),
            Fiddle::TYPE_VOIDP
          )
        end

        # TPUTS = Fiddle::Function.new(
        #   LIBTERMCAP['tputs'],
        # )

        SETUPTERM = Fiddle::Function.new(
          LIBTERMCAP['setupterm'],
          [
            Fiddle::TYPE_VOIDP,    # char *term
            Fiddle::TYPE_INT,      # int fildes
            Fiddle::TYPE_INTPTR_T, # int *errret
          ],
          Fiddle::TYPE_INT
        )
        private_constant :SETUPTERM

        TIGETSTR = Fiddle::Function.new(
          LIBTERMCAP['tigetstr'],
          [Fiddle::TYPE_VOIDP],
          Fiddle::TYPE_VOIDP
        )
        private_constant :TIGETSTR
      end

      private_constant :TermInfo
    end
  end
end
