# Docker Home Services Host

## Disclaimer

This project is not in any way designed to be a simple one-click-to-deploy project that let's you chose which software you want to run and can be tailored to your needs. It's my personal media services host config that I use at home in order to retrieve media, serve them over the network and host a Nextcloud instance.

If you're really looking for a complete, easy to configure and to use, media server deployment tool take a look at [Cloudbox](https://github.com/Cloudbox/Cloudbox) which uses Ansible and Docker to deploy the same services I use (and much more).

Because it's design is so heavily influenced by my personal tastes, you may prefer to just learn from it and take bits and pieces here and there rather than clone and run the whole thing as is.

Either way, I still try to be as concise as possible so that you can pretty much start from scratch with just this project and if someone happens to have a similar setup as me they can get up and running pretty easily just by reading this README.

## About the project

It leverages [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/) in order to bring up/host the services and [rsync](https://rsync.samba.org/) to backup the containers configuration files. The services that are hosted on the server are:

- [Watchtower](https://github.com/v2tec/watchtower): A simple service to automatically update your Docker containers as soon as their image is updated or on a fixed schedule.
- [Træfik](https://traefik.io/): A reverse-proxy that is very easy to configure and can automatically obtain Let's Encrypt certificates.
- [Portainer](https://www.portainer.io/): A simple management UI for Docker.
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

- Learn and use Ansible to replace docker-compose and all the setup scripts

## Context of my setup

I have a separate server running FreeNAS that host all my files. That's why I'm mounting datasets with NFS on the docker host. It's also the reason why I'm using rsync, my FreeNAS server is configured to pull my container config files from the docker host with rsync once per hour.

## Prerequisites

- Fedora Server 29+ (other Linux distributions are possible but you will need to adapt the setup scripts).
- A properly configured DNS server in your LAN as well as proper DNS entries with a domain suffix for your servers (populated by hand or automatically with the hostname of your devices).
- A paid domain name for which you have full control over.

## Installation

```bash
git clone https://github.com/PlqnK/docker-home-services-host.git
cd docker-home-services-host
for file in *.example*; do cp $file $(echo $file | sed -e 's/.example//'); done
```

You then need to:

- Adapt the NFS mount points in `docker-host-mount-points.txt` with what you have on your file server. You need to make it match the target 1:1, except for the source folder name which isn't important, otherwise you will need to modify every reference to the original target name in the `docker-compose.yml` file.
- Get a Plex claim token [here](https://www.plex.tv/claim/) and replace the `PLEX_CLAIM` variable in the `.env` file with it.
- Update every reference to `example.com` in the files with your personal domain name, every reference to `myserver` with either the hostname of your server with a proper domain suffix where needed. Change `USER` in `docker-host-setup.conf` to the name of the user created during the installation of Fedora/Ubuntu.
- Fill in passwords for `TRANSMISSION_RPC_PASSWORD`, `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` in `.env` as well as rsync in `docker-host-rsyncd.secrets`.
- Modify the `OPENVPN_PROVIDER`, `OPENVPN_USERNAME` and `OPENVPN_PASSWORD` according to the doc [here](https://hub.docker.com/r/haugene/transmission-openvpn/). If you have a provider that doesn't use credentials you will need to set `OPENVPN_PROVIDER` to `custom` and place your OpenVPN profile file inside the working dir as `custom.ovpn`.
- Adapt the rest of the variables in .env and other conf files according to your needs.

Install htpasswd with:

```bash
sudo dnf install httpd-tools
```

Then choose a password for the Træfik web interface and hash it as followed:

```bash
htpasswd -nb admin yourchosenpassword
```

Replace `yourpasswordhash` in `traefik.toml` under `entryPoints.traefik.auth.basic` with the hash that you just obtained.

Next, chmod and execute the setup script:

```bash
chmod u+x fedora-setup.sh
sudo ./fedora-setup.sh
```

You can then create and run your containers with a simple:

```bash
docker-compose up -d
```

Run the post install script which will modify some services config files that were created during the first run:

```bash
sudo ./post-first-launch.sh
```

Finally, in order to backup your containers config files you will need to configure your file server to pull files from the docker host using rsync in "module mode" with the module named `docker_backup` configured in the `docker-host-rsyncd.example.conf` file.

## Updating

Because this project uses Watchtower, containers are updated automatically every monday at 5 a.m. If you want to manually update your containers, just run:

```bash
cd /path/to/docker-home-services-host
docker-compose pull && docker-compose up -d
```

If you also want to update the source files of the project you just need to run `git pull` right before `docker-compose pull && docker-compose up -d`.

## Contributing

Contributions are welcome if you see any area of improvement!

There's no specific guidelines for pull requests but keep in mind that this project is tailored to my needs and, for example, I might not agree with what you think should be added.

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause). A copy of the license is available in this project folder.
