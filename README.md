# Ansible Docker Home Services

## Disclaimer

This project is not in any way designed to be a simple one-click-to-deploy project that let's you chose which software you want to run and can be tailored to your needs. It's my personal media services host config that I use at home in order to retrieve media, serve them over the network and host a Nextcloud instance.

If you're really looking for a complete, easy to configure and to use, media server deployment tool take a look at [Cloudbox](https://github.com/Cloudbox/Cloudbox) which uses Ansible and Docker to deploy the same services I use (and much more).

Because it's design is so heavily influenced by my personal tastes, you may prefer to just learn from it and take bits and pieces here and there rather than clone and run the whole thing as is.

Either way, I still try to be as concise as possible so that you can pretty much start from scratch with just this project and if someone happens to have a similar setup as me they can get up and running pretty easily just by reading this README.

## About the project

It leverages [Ansible](https://www.ansible.com/) to deploy the services and [Docker](https://www.docker.com/) to run them. It also uses [rsync](https://rsync.samba.org/) to backup the containers configuration files.

Everything is tailored to run on a minimal Fedora Server installation, it follows security best practices by not disabling the firewall and/or SELinux but by configuring them in order to maintain the security of the default install.  
It's also using a proxy for the docker socket in the form of a container. It restricts the API endpoints that can be used by the other containers and avoids having to mount the socket in a container accessible from the internet.

The services that are hosted on the server are:

- [Watchtower](https://github.com/v2tec/watchtower): A simple service to automatically update your Docker containers as soon as their image is updated or on a fixed schedule.
- [Træfik](https://traefik.io/): A reverse-proxy that is very easy to configure and can automatically obtain Let's Encrypt certificates.
- [Organizr](https://github.com/causefx/Organizr): Bring all your services web interfaces into one single centralized web interface.
- [Transmission](https://transmissionbt.com/): An easy to use BitTorrent client to downloads files using the BitTorrent protocol.
- [SABnzbd](https://sabnzbd.org/): An easy to use binary newsreader to download files using the Usenet protocol.
- [Jackett](https://github.com/Jackett/Jackett): A proxy server that helps interface PVR programs (Radarr, Sonarr, Lidarr etc.) and your BitTorrent trackers.
- [NZBHydra 2](https://github.com/theotherp/nzbhydra2): A meta search software for NZB indexers, you can configure and then search all your NZB indexers in one place.
- [Sonarr](https://sonarr.tv/), [Radarr](https://radarr.video/) and [Lidarr](https://lidarr.audio/): PVR programs for managing TV Shows, Movies and Music respectively. They will automatically monitor, grab and send the wanted file to a specified binary newsreader or BitTorrent downloader then rename and organize the resulting download according to your own preferences.
- [Bazarr](https://github.com/morpheus65535/bazarr): Companion application to Sonarr and Radarr, it manages and downloads subtitles based on your requirements.
- [LazyLibrarian](https://github.com/DobyTang/LazyLibrarian): Ebook library downloader and manager, works like Sonarr/Radarr/Lidarr.
- [Ombi](https://ombi.io/): Give your users the ability to request missing media content from your media collection.
- [Plex Media Server](https://www.plex.tv/): Plex is a centralised media server solution that let you organize your personal video, music as well as photo collections and streams them to all of your devices with a consistent interface.
- [Tautulli](https://tautulli.com/): Tautulli is a 3rd party program that runs alongside a Plex Media Server instance to monitor it's activity and track various statistics that Plex doesn't show in it's own interface.
- [Calibre-Web](https://github.com/janeczku/calibre-web): Calibre-Web is a web app providing a clean interface for browsing, reading and downloading ebooks using an existing Calibre database.
- [Nextcloud](https://nextcloud.com/): It's a suite of client-server software for creating and using file hosting services. It is functionally similar to Google Drive, although Nextcloud is free and open-source, allowing anyone to self-host an instance.
- [Collabora Online](https://www.collaboraoffice.com/collabora-online/): A powerfull web-based LibreOffice suite that features collaborative editing and which can be integrated in Nextcloud.

## Roadmap

Services to consider:

- Add [openHAB](https://www.openhab.org/) and/or [Home Assistant](https://www.home-assistant.io/) as a home automation hub (will maybe run it on a separate Raspberry Pi instead)
- Add [Grafana](https://grafana.com/) & [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/) + [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) / [Prometheus](https://prometheus.io/) or even the [Elastic Stack](https://www.elastic.co/products) to properly monitor devices, operating systems and services

Project:

- Add some monitoring.

## Context of my setup

I have a separate server running FreeNAS that host all my files. That's why I'm mounting datasets with NFS on the docker host. It's also the reason why I'm using rsync, my FreeNAS server is configured to pull my container config files from the docker host with rsync once per hour.

## Test environment

### Prerequisites

- Linux, macOS or Windows with [WSL](https://docs.microsoft.com/en-us/windows/wsl/about) (required for the `ansible` Vagrant provisioner)
- [Vagrant](https://www.vagrantup.com/)
- [KVM](https://www.linux-kvm.org/page/Main_Page) hypervisor, [libvirt](https://libvirt.org/) and the [Vagrant Libvirt Provider plugin](https://github.com/vagrant-libvirt/vagrant-libvirt) for Linux ([Virtualbox](https://www.virtualbox.org) is also possible for macOS and Windows users but you will need to adapt the Vagrantfile as well as the path to the ssh private key in the Vagrant inventory file)
- A local DNS resolver that can resolve `*.localhost.localdomain` to `127.0.0.1` ([systemd-resolved](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html) on Linux, [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) on Linux/macOS and [Acrylic DNS](http://mayakron.altervista.org/wikibase/show.php?id=AcrylicHome) on Windows)

See here for instructions on how to use Vagrant inside WSL to command Vagrant on the Windows host: <https://www.vagrantup.com/docs/other/wsl.html>.

### Launch instructions

Clone the repository and launch Vagrant:

```bash
git clone https://github.com/PlqnK/ansible-docker-home-services.git
cd ansible-docker-home-services
vagrant up
```

Vagrant will create a VM via libvirt using KVM and provision it with the Ansible playbook of this repository.

### Usage

When the provisioning is finished, you can open a web browser and navigate to any of the services web interface by typing <https://[name_of_the_service].localhost.localdomain>.

The Vagrant documentation is available here : <https://www.vagrantup.com/docs/>.

## Production environment

### Prerequisites

For the Ansible Master:

- Linux, macOS or Windows with WSL
- Ansible
- A SSH key

For the services host:

- Fedora Server 30 (other Linux distributions are possible but you will need to adapt the roles and playbooks).
- The SSH key of the Ansible Master copied to the Server.
- A properly configured DNS server in your LAN as well as DNS entries with a domain suffix for your servers (populated by hand or automatically with the hostname of your devices).
- A paid domain name for which you have full control over.

For the file server:

- NFS exports for your datasets.
- Rsync client.

### Personalization

First, you need to clone the repository:

```bash
git clone https://github.com/PlqnK/ansible-docker-home-services.git
cd ansible-docker-home-services
```

You then need to replace my encrypted production `host_vars` file with the Vagrant one:

```bash
cp inventories/vagrant/host_vars/services-host.yml inventories/production/host_vars/services-host.yml
```

And change it's values to your taste.

> **Notes**:  
> To get a Plex claim token, see [here](https://www.plex.tv/claim/).  
> To generate a password hash for Traefik, use [htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html).

### Deployment

```bash
ansible-playbook -i inventories/production/hosts playbook.yml
```

> **Note**: you also need the pass the argument `--ask-vault-pass` if you're using [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) to encrypt some variables.

In order to backup your containers config files you will need to configure your file server to pull files from the services host using rsync in "module mode" with the module named `docker_backup`.

### Updating the configuration

Ansible is idempotent, in order to update the configuration of your server according to the changes of this repository you only need to udpate the source files and re-execute the playbook:

```bash
git pull
ansible-playbook -i inventories/production/hosts playbook.yml
```

It will only update what needs to be updated.

### Updating the containers

Because this project uses Watchtower, containers are automatically updated every monday at 5 a.m. If you want to manually update your containers, just run:

```bash
ansible-playbook -i inventories/production/hosts playbook.yml --tags "update_containers"
```

### Usage

When the provisioning is finished, you can open a web browser and navigate to any of the services web interface by typing <https://[name_of_the_service].yourdomain.tld>.

## Contributing

Issues and PR are welcome if you're having problems or if you see any area of improvement!

This project is following the Ansible Styleguide from WhiteCloud, available here: <https://github.com/whitecloud/ansible-styleguide> and the Shell Styleguide from Google, available here: <https://google.github.io/styleguide/shell.xml>.

There's no specific guidelines for pull requests but keep in mind that this project is tailored to my needs and, for example, I might not agree with what you think should be added.

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause). A copy of the license is available in this project folder.
