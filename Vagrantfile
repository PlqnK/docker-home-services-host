# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "fedora/29-cloud-base"

  config.vm.network "forwarded_port", guest: 80, host: 80, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 443, host: 443, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8080, host: 8080, host_ip: "127.0.0.1"

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "libvirt" do |libvirt|
    libvirt.cpus = 4
    libvirt.memory = 4096
  end

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "playbook.yml"
    ansible.inventory_path = "inventories/vagrant"
    #ansible.ask_vault_pass = true
  end
end
