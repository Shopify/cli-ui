Dev UI
---

Dev UI is a small framework who's only responsibility is to print pretty to the terminal

- [Master Documentation](http://www.rubydoc.info/github/Shopify/dev-ui/master/Dev/UI)
- [Documentation of the Rubygems version](http://www.rubydoc.info/gems/dev-ui/)
- [Rubygems](https://rubygems.org/gems/dev-ui)

## Features

This may not be an exhaustive list. Please check our [documentation](http://www.rubydoc.info/github/Shopify/dev-ui/master/Dev/UI) for more information.

### Nested framing
To handle content flow (see example below)

```ruby
Dev::UI::StdoutRouter.enable
Dev::UI::Frame.open('Frame 1') do
  Dev::UI::Frame.open('Frame 2') { puts "inside frame 2" }
  puts "inside frame 1" 
end
```

![Nested Framing](https://user-images.githubusercontent.com/3074765/33799861-cb5dcb5c-dd01-11e7-977e-6fad38cee08c.png)

### Interactive Prompts
Prompt user with options and ask them to choose. Can answer using arrow keys, numbers, or vim bindings (or y/n for yes/no questions)

```ruby
Dev::UI.ask('What language/framework do you use?', options: %w(rails go ruby python))
Dev::UI::InteractivePrompt.call(%w(rails go ruby python))
```

![Interactive Prompt](https://user-images.githubusercontent.com/3074765/33797984-0ebb5e64-dcdf-11e7-9e7e-7204f279cece.gif)

### Free form text prompts

```ruby
Dev::UI.ask('Is Dev UI Awesome?', default: 'It is great!')
```

  ![Free form text prompt](https://user-images.githubusercontent.com/3074765/33799822-47f23302-dd01-11e7-82f3-9072a5a5f611.png)

### Spinner groups
Handle many multi-threaded processes while suppressing output unless there is an issue. Can update title to show state.


```ruby
spin_group = Dev::UI::SpinGroup.new
spin_group.add('Title')   { |spinner| sleep 3.0 }
spin_group.add('Title 2') { |spinner| sleep 3.0; spinner.update_title('New Title'); sleep 3.0 }
spin_group.wait
```

![Spinner Group](https://user-images.githubusercontent.com/3074765/33798295-d94fd822-dce3-11e7-819b-43e5502d490e.gif)

### Text Color formatting
e.g. `{{red:Red}} {{green:Green}}`

```ruby
puts Dev::UI.fmt "{{red:Red}} {{green:Green}}"
```

  ![Text Format](https://user-images.githubusercontent.com/3074765/33799827-6d0721a2-dd01-11e7-9ab5-c3d455264afe.png)

### Symbol/Glyph Formatting
e.g. `{{*}}` => a yellow ⭑

```ruby
puts Dev::UI.fmt "{{*}} {{x}} {{?}} {{v}}"
```

![Symbol Formatting](https://user-images.githubusercontent.com/3074765/33799847-9ec03fd0-dd01-11e7-93f7-5f5cc540e61e.png)

### Progress Bar

Show progress of a process or operation.

```ruby
Dev::UI::Progress.progress do |bar|
  100.times do
    bar.tick
  end
end
```

![Progress Bar](https://user-images.githubusercontent.com/3074765/33799794-cc4c940e-dd00-11e7-9bdc-90f77ec9167c.gif)

## Installation

```bash
gem install dev-ui
```

or add the following to your Gemfile:

```ruby
gem 'dev-ui'
```

In your code, simply add a `require 'dev/ui'`. Most options assume `Dev::UI::StdoutRouter.enable` has been called.

## Example Usage

The following code makes use of nested-framing, multi-threaded spinners, formatted text, and more.

```ruby
require 'dev/ui'

Dev::UI::StdoutRouter.enable

Dev::UI::Frame.open('{{*}} {{bold:a}}', color: :green) do
  Dev::UI::Frame.open('{{i}} b', color: :magenta) do
    Dev::UI::Frame.open('{{?}} c', color: :cyan) do
      sg = Dev::UI::SpinGroup.new
      sg.add('wow') do |spinner|
        sleep(2.5)
        spinner.update_title('second round!')
        sleep (1.0)
      end
      sg.add('such spin') { sleep(1.6) }
      sg.add('many glyph') { sleep(2.0) }
      sg.wait
    end
  end
  Dev::UI::Frame.divider('{{v}} lol')
  puts Dev::UI.fmt '{{info:words}} {{red:oh no!}} {{green:success!}}'
  sg = Dev::UI::SpinGroup.new
  sg.add('more spins') { sleep(0.5) ; raise 'oh no' }
  sg.wait
end
```

Output:

![Example Output](https://user-images.githubusercontent.com/3074765/33797758-7a54c7cc-dcdb-11e7-918e-a47c9689f068.gif)
