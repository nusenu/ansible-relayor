Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
     echo 'FreeBSD: { url: "https://pkg.FreeBSD.org/${ABI}/quarterly" , signature_type: "fingerprints", fingerprints: "/usr/share/keys/pkg", enabled: yes }' > /etc/pkg/FreeBSD.conf
     sudo pkg install -y python
  SHELL
end
