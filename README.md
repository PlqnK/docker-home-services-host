# Docker Media Services Host

This is my personal media services host config that I use at home in order to retrieve media and serve them over the network. I also use it to host a Nextcloud instance.
It leverages [Docker](https://www.docker.com/), [docker-compose](https://docs.docker.com/compose/) and [Træfik](https://traefik.io/).

## Context

I'm hosting my files on a separate server, that's why I'm using NFS to mount my datasets on the docker host. It's also the reason why I'm using rsync, in order to backup my containers configuration files.
I have a personnal domain name, with a subdomain that I use as a Dynamic DNS because I'm hosting everything at home and I don't have a static IP. I then have a wildcard CNAME record pointing to that previously mentioned subdomain.
For example, if you have the domain `example.com`, you need to set up `dyn.example.com` as a Dynamic DNS record. Then you need to create a CNAME record `*.example.com.` pointing to `dyn.example.com`, that way whenever `dyn.example.com` is updated to a new IP by your Dynamic DNS service running on your machine every subdomains will also points to the new IP!

## Prerequisites

- Ubuntu Server or Fedora Server (others are possible but you will need to adapt the setup scripts)
- A personal domain name
- A DNS provider supported by ACME, see here https://docs.traefik.io/configuration/acme/#provider (I'm using OVH as my registrar and DNS provider, if you are using something else you will need to make adjustments to the `docker-compose.yml`, the `traefik.toml` as well as the `.env` files in order to correctly configure your provider in the Træfik container.)

## Installation

```shell-script
git clone https://github.com/plqnk/docker-media-services-host.git
cd docker-media-services-host
for file in *.example; do cp -- "$file" "${file%%.example}"; done
```
You then need to:

- Adapt the NFS mount points in `docker-host-mount-points.txt` with what you have on your file server.
- Get an API token from your DNS provider and add it to the `.env` file.
- Get a Plex claim token here https://www.plex.tv/claim/ and replace the `PLEX_CLAIM` variable in the `.env` file with it.
- Update every reference to `example.com` in the files with your personal domain name, every reference to `myserver` with either the hostname of your server or the IP address where needed. Change `USER` in `docker-host-setup.conf` to the name of the user created during the installation of Ubuntu/Fedora.
- Fill in passwords for `TRANSMISSION_RPC_PASSWORD`, `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` in `.env` as well as rsync in `docker-host-rsyncd.secrets`.
- Modify the `OPENVPN_PROVIDER`, `OPENVPN_USERNAME` and `OPENVPN_PASSWORD` according to the doc here https://hub.docker.com/r/haugene/transmission-openvpn/. If you have a provider that doesn't use credentials you will need to set `OPENVPN_PROVIDER` to `custom` and place your OpenVPN profile file inside the working dir as `custom.ovpn`.
- Adapt the rest of the variables in .env and other conf files according to your needs.

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
Choose a password for Træfik and hash it as followed:
```shell-script
htpasswd -nb admin yourchosenpassword
```
Replace `yourpasswordhash` in `traefik.toml` under `entryPoints.traefik.auth.basic` with the hash that you just obtained.

For rsync you will now need to configure your file server in order to pull files from the docker host.
And finally:
```shell-script
docker network create proxy
docker-compose up -d
```
## Contributing

Contributions are welcome if you see any area of improvement!

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause).