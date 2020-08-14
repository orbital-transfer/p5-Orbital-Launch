use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::Vagrant::Helper;
# ABSTRACT: Vagrant helper code

use Modern::Perl;
use Mu;
use CLI::Osprey;
use Data::Section -setup;

method run() {
	my $header = $self->section_data( 'header.rb' );
	print $$header;
}

1;
__DATA__
__[ header.rb ]__
require "etc"

# From <https://superuser.com/questions/701735/run-script-on-host-machine-during-vagrant-up/992220#992220>
module LocalCommand
    class Config < Vagrant.plugin("2", :config)
        attr_accessor :command
    end

    class Plugin < Vagrant.plugin("2")
        name "local_shell"

        config(:local_shell, :provisioner) do
            Config
        end

        provisioner(:local_shell) do
            Provisioner
        end
    end

    class Provisioner < Vagrant.plugin("2", :provisioner)
        def provision
            result = system "#{config.command}"
        end
    end
end

# From <https://github.com/aidanns/vagrant-reload/blob/master/lib/vagrant-reload.rb>
module VagrantPlugins
  module Reload

    VERSION = "0.0.1"

    class Plugin < Vagrant.plugin("2")
      name "Reload"
      description <<-DESC
      The reload plugin allows a VM to be reloaded as a provisioning step.
      DESC

      provisioner "reload" do
        class ReloadProvisioner < Vagrant.plugin("2", :provisioner)

          def initialize(machine, config)
            super
          end

          def configure(root_config)
          end

          def provision
            options = {}
            options[:provision_ignore_sentinel] = false
            options[:force_halt] = true
            @machine.action(:halt, force_halt: options[:force_halt])
            @machine.action(:reload, options)
            begin
              sleep 10
            end until @machine.communicate.ready?
          end

          def cleanup
          end

        end
        ReloadProvisioner

      end
    end
  end
end

def create_and_add_ssh_key()
	privkey_path = '.id_vagrant'
	pubkey_path = '.id_vagrant.pub'
	authorized_keys_path = File.expand_path("~/.ssh/authorized_keys")

	if not File.exists?(privkey_path)
		system('ssh-keygen -N "" -f .id_vagrant')
		# add the current directory to the end
		pubkey = File.readlines(pubkey_path)[0].chomp
		File.write( pubkey_path,
			"#{pubkey} #{File.absolute_path(pubkey_path)}\n" )
	end

	pubkey = File.readlines(pubkey_path)[0]
	if not File.exists?(authorized_keys_path) or
			not File.readlines(authorized_keys_path).include?(pubkey)
		# append the key to the file
		open(authorized_keys_path, 'a') do |f|
			f.puts pubkey
		end
	end

	privkey = File.readlines(privkey_path).join("")
	return privkey
end
@privkey = create_and_add_ssh_key()

def configure_windows(win10, name)
	win10.ssh.username = "IEUser"
	# Do not need to use password authentication since we will install our own key.
	#win10.ssh.password = "Passw0rd!"
	win10.ssh.private_key_path = '.id_vagrant'
	win10.vm.boot_timeout = 2

	# This does not work, so we use the SSH pipe approach.
	#config.vm.provision "file", source: ".id_vagrant.pub", destination: "~/.ssh/authorized_keys"

	# Disable the default synced folder.
	win10.vm.synced_folder ".", "/vagrant", disabled: true

	# Sends the SSH key over a pipe.
	win10.vm.provision "add ssh public key", type: "local_shell", command: <<~SHELL
		sshpass -p 'Passw0rd!' vagrant ssh #{name} -- 'IFS=$'\''\\n'\''; while read -r; do printf "%s\\n" $REPLY >> ~/.ssh/authorized_keys ; done' < .id_vagrant.pub
	SHELL

	win10.ssh.insert_key = true

	win10.vm.provision "Install Chocolatey", type: "local_shell", command: <<~SHELL
		sshpass -p 'Passw0rd!' vagrant ssh #{name} -- "PowerShell -Command 'Set-ExecutionPolicy Bypass -Scope Process -Force; [Net.ServicePointManager]::SecurityProtocol = \\"tls12, tls11, tls\\"; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex'"
		sshpass -p 'Passw0rd!' vagrant ssh #{name} -- 'export PATH="$PATH:/cygdrive/c/ProgramData/chocolatey/bin"; choco install -y --allowemptychecksum sysinternals'
		sshpass -p 'Passw0rd!' vagrant ssh #{name} -- 'export PATH="$PATH:/cygdrive/c/ProgramData/chocolatey/bin"; choco install -y --allowemptychecksum strawberryperl'
		sshpass -p 'Passw0rd!' vagrant ssh #{name} -- 'export PATH="$PATH:/cygdrive/c/ProgramData/chocolatey/bin"; choco install -y --allowemptychecksum git'
		sshpass -p 'Passw0rd!' vagrant ssh #{name} -- 'export PATH="$PATH:/cygdrive/c/ProgramData/chocolatey/bin"; choco install -y --allowemptychecksum msys2 --params " /InstallDir:C:/msys64"'
	SHELL

	## Start VBoxSDL:
	##   VBoxSDL --startvm $(cat ./.vagrant/machines/win10/virtualbox/id) --separate
	# path C:\strawberry\perl\bin;C:\strawberry\perl\site\bin;C:\strawberry\c\bin;%PATH%
	# path C:\Program Files\Git\bin;%PATH%

	#win10.vm.provision :reload
end

def add_synced_folders_helper( config, directories, relative_directory, options = {} )
	for project_dir in directories do
		host_dir = File.absolute_path(project_dir)
		guest_basename = File.basename( project_dir )
		guest_dir_rel = "#{relative_directory}/#{guest_basename}"
		if options[:type] == 'sshfs'
			top = '~' # shell will expand this
			guest_dir = "#{top}/#{guest_dir_rel}"
			config.vm.provision :shell, privileged: false,
				run: "always",
				inline: <<~SHELL
					# if directory does not exist or is empty
					if [ ! -d #{guest_dir} ] || [ ! "$(ls -A #{guest_dir})"  ] ; then
						mkdir -p #{guest_dir};
						sshfs #{Etc.getlogin}@10.0.2.2:#{host_dir} #{guest_dir};
					fi
				SHELL
		elsif options[:type] == 'rsync'
			top = '/home/vagrant'
			guest_dir = "#{top}/#{guest_dir_rel}"
			config.vm.synced_folder( host_dir, guest_dir,
				type: 'rsync',
				rsync__exclude: '.git/' )
		else
			top = '/home/vagrant'
			guest_dir = "#{top}/#{guest_dir_rel}"
			config.vm.synced_folder( host_dir, guest_dir )
		end
	end

end
