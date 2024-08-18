Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo pkg install -y python
  SHELL
end
