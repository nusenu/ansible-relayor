Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo pkg_add python3
     sudo ln -s /usr/local/bin/python3 /usr/bin/python
     # temporary workaround for hashicorp/vagrant/pull/12584
     sudo echo PubkeyAcceptedAlgorithms +ssh-rsa >> /etc/ssh/sshd_config
     sudo rcctl restart sshd
  SHELL
end
