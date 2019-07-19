# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "fedora/30-cloud-base"

  config.vm.hostname = "docker-host"

  config.vm.network "private_network", ip: "192.168.121.100"
  config.vm.network "forwarded_port", guest: 80, host: 80
  config.vm.network "forwarded_port", guest: 443, host: 443

  config.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"

  config.vm.provider "libvirt" do |libvirt|
    libvirt.cpus = 4
    libvirt.memory = 4096
  end

  # In order to be as close as the production environment, I need to configure an NFS server so that I can mount
  # the NFS shares in the Ansible playbook later.
  config.vm.provision "Simulate production environment", type: "shell", path: "vagrant/simul_prod_env.sh"

  config.vm.provision "Provision the host", type: "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
    ansible.inventory_path = "inventories/vagrant/hosts"
    ansible.limit = "all"
    ansible.ask_vault_pass = true
  end
end
