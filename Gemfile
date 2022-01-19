# NOTE: These are development-only dependencies
source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'rubocop'
  gem 'rubocop-rake'
  gem 'rubocop-shopify'
  gem 'rubocop-sorbet'
  gem 'byebug', platforms: [:mri]
  gem 'method_source'
  gem 'simplecov'
end

group :typecheck do
  gem 'sorbet-static-and-runtime'
  gem 'tapioca', require: false
end

group :test do
  gem 'mocha', require: false
  gem 'minitest', '>= 5.0.0', require: false
  gem 'minitest-reporters', require: false
end
