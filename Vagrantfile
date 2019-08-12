# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define "docker-home-services" do |subconfig|
    subconfig.vm.box = "fedora/30-cloud-base"

    subconfig.vm.hostname = "docker-home-services.localdomain"

    subconfig.vm.network "private_network", ip: "192.168.121.100"
    subconfig.vm.network "forwarded_port", guest: 80, host: 80
    subconfig.vm.network "forwarded_port", guest: 443, host: 443

    subconfig.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"

    subconfig.vm.provider "libvirt" do |libvirt|
      libvirt.cpus = 4
      libvirt.memory = 4096
      # Remove the guest name prefix in libvirt which by default is the name of the current directory.
      libvirt.default_prefix = ""
    end
    subconfig.vm.provider "virtualbox" do |vbox|
      vbox.cpus = 4
      vbox.memory = 4096
      vbox.name = "docker-home-services"
    end

    # In order to be as close as the production environment, I need to configure an NFS server so that I can mount
    # the NFS shares in the Ansible playbook later.
    subconfig.vm.provision "Simulate production environment", type: "shell", path: "vagrant/simul_prod_env.sh"

    subconfig.vm.provision "Provision the host", type: "ansible" do |ansible|
      ansible.playbook = "playbook.yml"
      ansible.inventory_path = "inventories/vagrant/hosts"
      ansible.limit = "all"
      ansible.ask_vault_pass = true
    end
  end
end
