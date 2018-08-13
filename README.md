# Docker Media Services Host

## Disclaimer

This project is not in any way designed to be a simple one-click-to-deploy project that let's you chose which software you want to run and can be tailored to your needs. It's my personal media services host config that I use at home in order to retrieve media, serve them over the network and host a Nextcloud instance.

Because it's design is so heavily influenced by my personal tastes, you may prefer to use it as a learning tool (a working example) and just take bits and pieces here and there than just clone and run the whole thing as is.

Either way, I still try to be as concise as possible so that if someone has a similar setup as me they can get up and running pretty easily just by reading this README.

## About the project

It leverages [Docker](https://www.docker.com/) and [docker-compose](https://docs.docker.com/compose/) in order to bring up/host the services and [rsync](https://rsync.samba.org/) to backup the containers configuration files. The services that are hosted on the server are:

- [Watchtower](https://github.com/v2tec/watchtower): A simple service to automatically update your Docker containers as soon as their image is updated or on a fixed schedule.
- [Træfik](https://traefik.io/): A reverse-proxy that is very easy to configure and can automatically generate Let's Encrypt certificates.
- [Portainer](https://www.portainer.io/): A simple management UI for Docker.
- [Organizr](https://github.com/causefx/Organizr): Bring all your services webinterfaces into one single centralized interface.
- [Transmission](https://transmissionbt.com/): An easy to use program to downloads files using the BitTorrent protocol.
- [SABnzbd](https://sabnzbd.org/): An easy to use binary newsreader (download files using the Usenet protocol).
- [Jackett](https://github.com/Jackett/Jackett): A proxy server that helps interface PVR apps (Radarr, Sonarr, Lidarr etc.) and your BitTorrent trackers.
- [NZBHydra 2](https://github.com/theotherp/nzbhydra2): A meta search software for NZB indexers, you can configure and then search all your NZB indexers in one place.
- [Sonarr](https://sonarr.tv/), [Radarr](https://radarr.video/) and [Lidarr](https://lidarr.audio/): PVR programs for managing TV Shows, Movies and Music respectively. They will automatically monitor, grab and send the wanted file to a specified binary newsreader or BitTorrent downloader then rename and organize the resulting download according to your own preferences.
- [Ombi](https://ombi.io/): Give your users the ability to request missing media content.
- [Plex Media Server](https://www.plex.tv/): Plex is a centralised media server solution that let's you organize your personal video, music, and photo collections and streams them to all of your devices with a consistent interface.
- [Tautulli](https://tautulli.com/): Tautulli is a 3rd party application that runs alongside a Plex Media Server instance to monitor activity and track various statistics that Plex doesn't show in it's own interface.
- [Nextcloud](https://nextcloud.com/): It's a suite of client-server software for creating and using file hosting services. It is functionally similar to Google Drive, although Nextcloud is free and open-source, allowing anyone to self-host an instance.
- [Collabora Online](https://www.collaboraoffice.com/collabora-online/): A powerfull web-based LibreOffice suite that features collaborative editing that can integrated in Nextcloud.

## Roadmap

Services to consider:

- Add [LazyLibrarian](https://github.com/DobyTang/LazyLibrarian) + [Calibre](https://calibre-ebook.com/) + [Calibre-Web](https://github.com/janeczku/calibre-web) and [Mylar](https://github.com/evilhero/mylar) + [Ubooquity](http://vaemendis.net/ubooquity/) to retrieve and organise E-books and Comics
- Add [Beets](http://beets.io/) and/or [Musicbrainz](https://musicbrainz.org/) to organise and properly tag my music library
- Add [openHAB](https://www.openhab.org/) and/or [Home Assistant](https://www.home-assistant.io/) as a home automation hub
- Add [Grafana](https://grafana.com/) + [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/) & [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) to properly monitor my servers and services

Project:

- Learn and use Ansible to replace docker-compose and all the setup scripts

## Context of my setup

I have a separate server running FreeNAS that host all my files. That's why I'm mounting my primary datasets with NFS on the docker host. It's also the reason why I'm using rsync, my FreeNAS server is configured to pull my container config files from the docker host with rsync once per hour.

## Prerequisites

- Fedora Server 28+ or Ubuntu Server 18.04+ (other Linux distributions are possible but you will need to adapt the setup scripts)
- A properly configured DNS server in your LAN that, at least, all of your servers uses as well as proper DNS entries with a domain suffix (populated by hand or automatically with the hostname of your devices)
- A paid domain name for which you have full control over
- [Optionnal] A DNS provider supported by ACME, see here <https://docs.traefik.io/configuration/acme/#provider> (I'm using OVH as my registrar and DNS provider, if you are using something else you will need to make adjustments to the `docker-compose.yml`, the `traefik.toml` as well as the `.env` files in order to correctly configure your provider in the Træfik container.). If your provider is not supported by ACME then you can use the HTTP-01 challenge instead of the DNS-01 challenge.

## Installation

```bash
git clone https://github.com/plqnk/docker-media-services-host.git
cd docker-media-services-host
for file in *.example*; do cp $file $(echo $file | sed -e 's/.example//'); done
```

You then need to:

- Adapt the NFS mount points in `docker-host-mount-points.txt` with what you have on your file server.
- Get an API token from your DNS provider and add it to the `.env` file.
- Get a Plex claim token here <https://www.plex.tv/claim/> and replace the `PLEX_CLAIM` variable in the `.env` file with it.
- Update every reference to `example.com` in the files with your personal domain name, every reference to `myserver` with either the hostname of your server or the IP address where needed. Change `USER` in `docker-host-setup.conf` to the name of the user created during the installation of Ubuntu/Fedora.
- Fill in passwords for `TRANSMISSION_RPC_PASSWORD`, `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` in `.env` as well as rsync in `docker-host-rsyncd.secrets`.
- Modify the `OPENVPN_PROVIDER`, `OPENVPN_USERNAME` and `OPENVPN_PASSWORD` according to the doc here <https://hub.docker.com/r/haugene/transmission-openvpn/>. If you have a provider that doesn't use credentials you will need to set `OPENVPN_PROVIDER` to `custom` and place your OpenVPN profile file inside the working dir as `custom.ovpn`.
- Adapt the rest of the variables in .env and other conf files according to your needs.

If you are on Fedora, install htpasswd with:

```bash
sudo dnf install httpd-tools
```

If you are on Ubuntu, install it with:

```bash
sudo apt install apache2-utils
```

Then choose a password for Træfik and hash it as followed:

```bash
htpasswd -nb admin yourchosenpassword
```

Replace `yourpasswordhash` in `traefik.toml` under `entryPoints.traefik.auth.basic` with the hash that you just obtained.

Next, if you are on Fedora:

```bash
chmod u+x fedora-server-setup.sh
sudo ./fedora-server-setup.sh
```

Or, if you are on Ubuntu:

```bash
chmod u+x ubuntu-server-setup.sh
sudo ./ubuntu-server-setup.sh
```

You will need to create the docker proxy network and then you can then launch your containers:

```bash
docker network create proxy
docker-compose up -d
```

Run the post install script which will modify some services config files that were created during the first run:

```bash
sudo ./post-first-launch.sh
```

Finally, in order to backup you containers config files, you will need to configure your file server in order to pull files from the docker host using rsync in "module mode" with the module named `docker_backup` configured in the `docker-host-rsyncd.example.conf` file.

## Contributing

Contributions are welcome if you see any area of improvement!

There's no specific guidelines for PR but keep in mind that this project is tailored to my needs and I might not agree with what you think should be added for example.

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause). A copy of the license is available in this project.