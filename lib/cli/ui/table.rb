# typed: true

module CLI
  module UI
    module Table
      extend T::Sig

      class << self
        extend T::Sig

        # Prints a formatted table to the specified output
        # Automatically pads columns to align based on the longest cell in each column,
        # ignoring the width of ANSI color codes.
        #
        # ==== Attributes
        #
        # * +table+ - (required) 2D array of strings representing the table data
        #
        # ==== Options
        #
        # * +:col_spacing+ - Number of spaces between columns. Defaults to 1
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout
        #
        # ==== Example
        #
        #   CLI::UI::Table.puts_table([
        #     ["{{bold:header_1}}", "{{bold:header_2}}"],
        #     ["really_long_cell",  "short"],
        #     ["row2",              "row2"]
        #   ])
        #
        # Default Output:
        #   header_1         header_2
        #   really_long_cell short
        #   row2             row2
        #
        sig { params(table: T::Array[T::Array[String]], col_spacing: Integer, to: IOLike).void }
        def puts_table(table, col_spacing: 1, to: $stdout)
          col_sizes = table.transpose.map do |col|
            col.map { |cell| CLI::UI::ANSI.printing_width(CLI::UI.resolve_text(cell)) }.max
          end

          table.each do |row|
            padded_row = row.each_with_index.map do |cell, i|
              col_size = T.must(col_sizes[i]) # guaranteed to be non-nil
              cell_size = CLI::UI::ANSI.printing_width(CLI::UI.resolve_text(cell))
              padded_cell = cell + ' ' * (col_size - cell_size)
              padded_cell
            end
            CLI::UI.puts(padded_row.join(' ' * col_spacing), to: to)
          end
        end

        # Captures a table's output as an array of strings without printing to the terminal
        # Can be used to further manipulate or format the table output
        #
        # ==== Attributes
        #
        # * +table+ - (required) 2D array of strings representing the table data
        #
        # ==== Options
        #
        # * +:col_spacing+ - Number of spaces between columns. Defaults to 1
        #
        # ==== Returns
        #
        # * +Array[String]+ - Array of strings, each representing a row of the formatted table
        #
        # ==== Example
        #
        #   CLI::UI::Table.capture_table([
        #     ["{{bold:header_1}}", "{{bold:header_2}}"],
        #     ["really_long_cell",  "short"],
        #     ["row2",              "row2"]
        #   ])
        #
        sig { params(table: T::Array[T::Array[String]], col_spacing: Integer).returns(T::Array[String]) }
        def capture_table(table, col_spacing: 1)
          strio = StringIO.new
          puts_table(table, col_spacing: col_spacing, to: strio)
          strio.string.lines.map(&:chomp)
        end
      end
    end
  end
end
