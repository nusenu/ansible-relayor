Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo pkg_add python%2.7
     sudo ln -s /usr/local/bin/python2.7 /usr/bin/python
  SHELL
end
