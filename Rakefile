require 'dev/ui'
require 'rake/testtask'

TEST_ROOT = File.expand_path('../test', __FILE__)

Rake::TestTask.new do |t|
  t.libs += ["test"]
  t.test_files = FileList[File.join(TEST_ROOT, '**', '*_test.rb')]
  t.verbose = false
  t.warning = false
end

desc "Check rubocop styles"
task :style do
  sh "rubocop"
end

task default: [:test, :style]
