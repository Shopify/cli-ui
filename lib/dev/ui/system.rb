require 'dev/ui'

require 'open3'
require 'English'

module Dev
  module UI
    module System
      class << self
        SUDO_PROMPT = Dev::UI.fmt("{{info:(sudo)}} Password: ")

        # Ask for sudo access with a message explaning the need for it
        # Will make subsequent commands capable of running with sudo for a period of time
        #
        # #### Parameters
        # - `msg`: A message telling the user why sudo is needed
        #
        # #### Usage
        # `ctx.sudo_reason("We need to do a thing")`
        #
        def sudo_reason(msg)
          # See if sudo has a cached password
          `env SUDO_ASKPASS=/usr/bin/false sudo -A true`
          return if $CHILD_STATUS.success?
          Dev::UI.with_frame_color(:blue) do
            puts(Dev::UI.fmt("{{i}} #{msg}"))
          end
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        #
        # #### Returns
        # - `output`: output (STDOUT) of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out, stat = ctx.capture2('ls', 'a_folder')`
        #
        def capture2(*a, sudo: false, env: ENV)
          delegate_open3(*a, sudo: sudo, env: env, method: :capture2)
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        #
        # #### Returns
        # - `output`: output (STDOUT merged with STDERR) of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out_and_err, stat = ctx.capture2e('ls', 'a_folder')`
        #
        def capture2e(*a, sudo: false, env: ENV)
          delegate_open3(*a, sudo: sudo, env: env, method: :capture2e)
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        #
        # #### Returns
        # - `output`: STDOUT of the command execution
        # - `error`: STDERR of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out, err, stat = ctx.capture3('ls', 'a_folder')`
        #
        def capture3(*a, sudo: false, env: ENV)
          delegate_open3(*a, sudo: sudo, env: env, method: :capture3)
        end

        # Execute a command in the user's environment
        # Outputs result of the command without capturing it
        #
        # #### Parameters
        # - `*a`: A splat of arguments evaluated as a command. (e.g. `'rm', folder` is equivalent to `rm #{folder}`)
        # - `sudo`: If truthy, run this command with sudo. If String, pass to `sudo_reason`
        # - `env`: process environment with which to execute this command
        # - `**kwargs`: additional keyword arguments to pass to Process.spawn
        #
        # #### Returns
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `stat = ctx.system('ls', 'a_folder')`
        #
        def system(*a, sudo: false, env: ENV, **kwargs)
          a = apply_sudo(*a, sudo)

          out_r, out_w = IO.pipe
          err_r, err_w = IO.pipe
          in_stream = STDIN.closed? ? :close : STDIN
          pid = Process.spawn(env, *resolve_path(a, env), 0 => in_stream, :out => out_w, :err => err_w, **kwargs)
          out_w.close
          err_w.close

          handlers = if block_given?
            { out_r => ->(data) { yield(data.force_encoding(Encoding::UTF_8), '') },
              err_r => ->(data) { yield('', data.force_encoding(Encoding::UTF_8)) }, }
          else
            { out_r => ->(data) { STDOUT.write(data) },
              err_r => ->(data) { STDOUT.write(data) }, }
          end

          loop do
            ios = [err_r, out_r].reject(&:closed?)
            break if ios.empty?

            readers, = IO.select(ios)
            readers.each do |io|
              begin
                handlers[io].call(io.readpartial(4096))
              rescue IOError
                io.close
              end
            end
          end

          Process.wait(pid)
          $CHILD_STATUS
        end

        private

        def apply_sudo(*a, sudo)
          a.unshift('sudo', '-S', '-p', SUDO_PROMPT) if sudo
          sudo_reason(sudo) if sudo.is_a?(String)
          a
        end

        def delegate_open3(*a, sudo: raise, env: raise, method: raise)
          a = apply_sudo(*a, sudo)
          Open3.send(method, env, *resolve_path(a, env))
        rescue Errno::EINTR
          raise(Dev::Abort, "execution of command was interrupted (EINTR): #{a.join(' ')}")
        end

        # Ruby resolves the program to execute using its own PATH, but we want it to
        # use the provided one, so we ensure ruby chooses to spawn a shell, which will
        # parse our command and properly spawn our target using the provided environment.
        #
        # This is important because dev clobbers its own environment such that ruby
        # means /usr/bin/ruby, but we want it to select the ruby targeted by the active
        # project.
        #
        # See https://github.com/Shopify/dev/pull/625 for more details.
        def resolve_path(a, env)
          # If only one argument was provided, make sure it's interpreted by a shell.
          return ["true ; " + a[0]] if a.size == 1
          return a if a.first.include?('/')
          item = env.fetch('PATH', '').split(':').detect do |f|
            File.exist?("#{f}/#{a.first}")
          end
          a[0] = "#{item}/#{a.first}" if item
          a
        end
      end
    end
  end
end
