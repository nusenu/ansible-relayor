Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo pkg install -y python
     sudo ln -s /usr/local/bin/python /usr/bin/python
  SHELL
end
