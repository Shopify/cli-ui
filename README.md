```ruby
require 'dev/ui'

Dev::UI::StdoutRouter.enable

Dev::UI::Frame.open('{{*}} {{bold:a}}', color: :green) do
  Dev::UI::Frame.open('{{i}} b', color: :magenta) do
    Dev::UI::Frame.open('{{?}} c', color: :cyan) do
      sg = Dev::UI::SpinGroup.new
      sg.add('wow') { sleep(2.5) }
      sg.add('such spin') { sleep(1.6) }
      sg.add('many glyph') { sleep(2.0) }
      sg.wait
    end
  end
  Dev::UI::Frame.divider('{{v}} lol')
  puts 'words'
  sg = Dev::UI::SpinGroup.new
  sg.add('more spins') { sleep(0.5) ; raise 'oh no' }
  sg.wait
end
```
