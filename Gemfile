# frozen_string_literal: true

# NOTE: These are development-only dependencies
source 'https://rubygems.org'

gemspec

group :development, :test do
  # parallel 2.x requires Ruby >= 3.3, but CI runs 3.2. Pin to the last 1.x
  # release (supports Ruby >= 2.7). Pulled in transitively by rubocop/tapioca.
  gem 'parallel', '< 2'
  gem 'rubocop'
  gem 'rubocop-rake'
  gem 'rubocop-shopify'
  gem 'rubocop-sorbet'
  gem 'byebug', platforms: [:mri]
  gem 'method_source'
  gem 'simplecov'
end

group :typecheck do
  gem 'sorbet-static'
  gem 'tapioca', require: false
end

group :test do
  gem 'mocha', require: false
  gem 'minitest', require: false
  gem 'minitest-reporters', require: false
end
