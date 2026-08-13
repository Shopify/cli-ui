# typed: true
# frozen_string_literal: true

require 'open3'
require 'stringio'

# Regenerates the ANSI replay fixtures: `capture` re-renders the .raw captures
# from cli-ui itself, `bless` re-derives the .expected files from xterm.js.
# See test/fixtures/replay/README.md.
module ReplayFixtures
  DIR = File.expand_path('../test/fixtures/replay', __dir__)
  ORACLE = File.join(DIR, 'oracle.js')
  INSTALL = 'npm ci'

  # Holds every task until the group has repainted, so a capture records
  # spinner frames instead of a single paint.
  class Sink < StringIO
    #: Queue
    attr_reader :queue

    #: (Integer repaints, Integer tasks) -> void
    def initialize(repaints, tasks)
      super()
      @repaints = repaints
      @tasks = tasks
      @queue = Queue.new #: Queue
      @released = false #: bool
    end

    #: (*untyped args) -> untyped
    def print(*args)
      super.tap do
        next if @released || string.scan(/\e\[\d*A/).size < @repaints

        @released = true
        @tasks.times { @queue << true }
      end
    end
  end

  extend self

  #: -> void
  def capture
    require 'cli/ui'
    CLI::UI.enable_cursor = true
    CLI::UI.enable_color = true
    CLI::UI::StdoutRouter.ensure_activated

    spin_group('spin_group', ['install dependencies', 'compile assets', 'run migrations'], repaints: 8)
    spin_group('spin_group_wide_glyphs', ['日本語のタスク', '🔧 rebuild native extensions'], repaints: 4)
    retitling_spin_group('spin_group_retitled')
    progress_bar('progress_bar')
    frames('frame_nested')
    alternate_screen('alternate_screen_prompt')
  end

  #: -> void
  def bless
    raise "#{ORACLE} needs node and its locked packages:\n  cd #{DIR} && #{INSTALL}" unless node?

    Dir.glob(File.join(DIR, '*.raw')).sort.each do |raw|
      expected, status = Open3.capture2('node', ORACLE, raw)
      raise "oracle failed on #{File.basename(raw)}" unless status.success?

      write("#{File.basename(raw, ".raw")}.expected", expected)
    end
  end

  private

  #: -> bool
  def node?
    Open3.capture2e('node', '--version').last.success?
  rescue Errno::ENOENT
    false
  end

  #: (String name, String contents) -> void
  def write(name, contents)
    File.binwrite(File.join(DIR, name), contents)
    puts format('%-30s %6d B', name, contents.bytesize)
  end

  #: (String name, Array[String] titles, repaints: Integer) -> void
  def spin_group(name, titles, repaints:)
    to = Sink.new(repaints, titles.length)
    group = CLI::UI::SpinGroup.new(auto_debrief: false)
    titles.each { |title| group.add(title) { to.queue.pop(timeout: 5) } }
    group.wait(to: to)
    write("#{name}.raw", to.string)
  end

  #: (String name) -> void
  def retitling_spin_group(name)
    to = Sink.new(3, 1)
    group = CLI::UI::SpinGroup.new(auto_debrief: false)
    group.add('bundle install') do |task|
      3.times do |i|
        task.update_title("bundle install (gem #{i + 1})")
        sleep(0.12)
      end
      to.queue.pop(timeout: 5)
    end
    group.wait(to: to)
    write("#{name}.raw", to.string)
  end

  #: (String name) -> void
  def progress_bar(name)
    write("#{name}.raw", to_stdout do
      CLI::UI::Progress.progress('Building') do |bar|
        20.times { |i| bar.tick(set_percent: (i + 1) / 20.0) }
      end
    end)
  end

  #: (String name) -> void
  def frames(name)
    write("#{name}.raw", to_stdout do
      CLI::UI::Frame.open('Deploy') do
        puts CLI::UI.fmt('{{v}} checked out {{blue:main}}')
        CLI::UI::Frame.open('Migrate', color: :cyan) { puts '3 migrations applied' }
        puts 'done'
      end
    end)
  end

  # A full-screen prompt redrawing its selection, which a terminal discards on
  # exit: the replay must keep the main screen only.
  #: (String name) -> void
  def alternate_screen(name)
    tasks = CLI::UI.fmt("{{v}} one\n") + CLI::UI.fmt("{{v}} two\n")
    stream = +''
    stream << tasks
    stream << CLI::UI::ANSI.enter_alternate_screen << tasks
    stream << "? Which environment?  \n"
    stream << CLI::UI::ANSI.cursor_up(1) << CLI::UI::ANSI.cursor_horizontal_absolute(1)
    stream << "\e[K> production\n\e[K  staging" << CLI::UI::ANSI.previous_lines(1)
    stream << "\e[K  production\n\e[K> staging"
    stream << CLI::UI::ANSI.exit_alternate_screen
    stream << CLI::UI.fmt("{{v}} environment: staging\n")
    write("#{name}.raw", stream)
  end

  #: { -> void } -> String
  def to_stdout
    io = StringIO.new
    original = $stdout
    $stdout = io
    yield
    io.string
  ensure
    $stdout = original
  end
end

namespace :replay do
  desc 'Re-render the ANSI replay captures from cli-ui'
  task :capture do
    $LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
    ReplayFixtures.capture
  end

  desc 'Re-derive the ANSI replay expectations from xterm.js'
  task :bless do
    ReplayFixtures.bless
  end
end
