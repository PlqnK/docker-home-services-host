# Docker Media Services Host

This is my personal media services host config that I use at home in order to retrieve media and serve them over the network. I also use it to host a Nextcloud instance.

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

## Context of my personnal setup

I have a separate server running FreeNAS that host all my files. That's why I'm mounting my primary datasets with NFS on the docker host. It's also the reason why I'm using rsync, my FreeNAS server is configured to pull my container config files from the docker host with rsync once per hour.

I have a personnal domain name, with a subdomain that I use as a Dynamic DNS because I'm hosting everything at home and I don't have a static IP (the A record of that subdomain is automatically updated by my router when my public IP adress change).

## Prerequisites

- Ubuntu Server 18.04+ or Fedora Server 28+ (others are possible but you will need to adapt the setup scripts)
- A personal domain name
- [Optionnal] A DNS provider supported by ACME, see here https://docs.traefik.io/configuration/acme/#provider (I'm using OVH as my registrar and DNS provider, if you are using something else you will need to make adjustments to the `docker-compose.yml`, the `traefik.toml` as well as the `.env` files in order to correctly configure your provider in the Træfik container.). If your provider is not supported by ACME then you can use the HTTP-01 challenge instead of the DNS-01 challenge.

## Installation

```shell-script
git clone https://github.com/plqnk/docker-media-services-host.git
cd docker-media-services-host
for file in *.example*; do mv $file $(echo $file | sed -e 's/.example//'); done
```
You then need to:

- Adapt the NFS mount points in `docker-host-mount-points.txt` with what you have on your file server.
- Get an API token from your DNS provider and add it to the `.env` file.
- Get a Plex claim token here https://www.plex.tv/claim/ and replace the `PLEX_CLAIM` variable in the `.env` file with it.
- Update every reference to `example.com` in the files with your personal domain name, every reference to `myserver` with either the hostname of your server or the IP address where needed. Change `USER` in `docker-host-setup.conf` to the name of the user created during the installation of Ubuntu/Fedora.
- Fill in passwords for `TRANSMISSION_RPC_PASSWORD`, `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` in `.env` as well as rsync in `docker-host-rsyncd.secrets`.
- Modify the `OPENVPN_PROVIDER`, `OPENVPN_USERNAME` and `OPENVPN_PASSWORD` according to the doc here https://hub.docker.com/r/haugene/transmission-openvpn/. If you have a provider that doesn't use credentials you will need to set `OPENVPN_PROVIDER` to `custom` and place your OpenVPN profile file inside the working dir as `custom.ovpn`.
- Adapt the rest of the variables in .env and other conf files according to your needs.

If you are on Ubuntu, install htpasswd with:
```shell-script
sudo apt install apache2-utils
```
If you are on Fedora, install it with:
```shell-script
sudo dnf install httpd-tools
```
Then choose a password for Træfik and hash it as followed:
```shell-script
htpasswd -nb admin yourchosenpassword
```
Replace `yourpasswordhash` in `traefik.toml` under `entryPoints.traefik.auth.basic` with the hash that you just obtained.

Next, if you are on Ubuntu:
```shell-script
chmod u+x ubuntu-server-setup.sh
sudo ./ubuntu-server-setup.sh
```
Or if you are on Fedora:
```shell-script
chmod u+x fedora-server-setup.sh
sudo ./fedora-server-setup.sh
```
For rsync you will now need to configure your file server in order to pull files from the docker host.
You need to create the docker proxy network and you can then launch your containers:
```shell-script
docker network create proxy
docker-compose up -d
```
And finally run the post install script which will modify some services config files:
```shell-script
sudo ./post-first-launch.sh
```

## Contributing

Contributions are welcome if you see any area of improvement!

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause).