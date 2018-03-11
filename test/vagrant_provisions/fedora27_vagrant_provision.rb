Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo dnf install -y python2
  SHELL
end
