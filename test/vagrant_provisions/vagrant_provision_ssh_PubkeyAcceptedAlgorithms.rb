Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     sudo echo PubkeyAcceptedAlgorithms +ssh-rsa >> /etc/ssh/sshd_config
     sudo sudo systemctl restart sshd
  SHELL
end
