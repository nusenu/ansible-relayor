Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo pkg_add python3
     sudo ln -s /usr/local/bin/python3 /usr/bin/python
  SHELL
end
