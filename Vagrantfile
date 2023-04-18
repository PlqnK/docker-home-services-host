# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.hostmanager.enabled = false
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = true
  config.hostmanager.include_offline = true

  config.vm.define "storage" do |subconfig|
    subconfig.vm.box = "generic/freebsd13"
    subconfig.vm.hostname = "storage.localdomain"

    subconfig.vm.synced_folder ".", "/vagrant", disabled: true

    subconfig.vm.provider "libvirt" do |libvirt|
      libvirt.cpus = 1
      libvirt.memory = 1024
      libvirt.default_prefix = ""
    end
    
    subconfig.vm.provision :hostmanager
    subconfig.vm.provision "Provision the storage", type: "shell", path:"vagrant/storage_provisioning.sh"
  end

  config.vm.define "media" do |subconfig|
    subconfig.vm.box = "fedora/37-cloud-base"
    subconfig.vm.hostname = "media.localdomain"

    subconfig.vm.network "forwarded_port", guest: 80, host: 8080
    subconfig.vm.network "forwarded_port", guest: 443, host: 8443

    subconfig.vm.synced_folder ".", "/vagrant", disabled: true

    subconfig.vm.provider "libvirt" do |libvirt|
      libvirt.cpus = 2
      libvirt.memory = 4096
      libvirt.default_prefix = ""
    end

    subconfig.vm.provision :hostmanager
    subconfig.vm.provision "Provision the host", type: "ansible" do |ansible|
      ansible.playbook = "playbook.yml"
      ansible.inventory_path = "inventories/vagrant.yml"
      ansible.limit = "all"
    end
  end
end
