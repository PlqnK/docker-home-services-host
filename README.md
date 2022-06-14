# Docker Home Services Host

## Disclaimer

This project is not in any way designed to be a simple one-click-to-deploy project that let's you chose which software you want to run and can be tailored to your needs. It's my personal media services host config that I use at home in order to retrieve media, serve them over the network and host a Nextcloud instance.

If you're really looking for a complete, easy to configure and to use, media server deployment tool take a look at [Cloudbox](https://github.com/Cloudbox/Cloudbox) which uses Ansible and Docker to deploy the same services I use (and much more).

Because it's design is so heavily influenced by my personal tastes, you may prefer to just learn from it and take bits and pieces here and there rather than clone and run the whole thing as is.

Either way, I still try to be as concise as possible so that you can pretty much start from scratch with just this project and if someone happens to have a similar setup as me they can get up and running pretty easily just by reading this README.

## About the project

It leverages [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/) in order to bring up/host the services. The high level services that are hosted on the server are:

- [Træfik](https://traefik.io/)
  - A reverse-proxy that is very easy to configure and can automatically obtain Let's Encrypt certificates.
- [Transmission](https://transmissionbt.com/)
  - A BitTorrent client to downloads files using the BitTorrent protocol.
- [SABnzbd](https://sabnzbd.org/)
  - A binary newsreader to download files using the Usenet protocol.
- [Prowlarr](https://github.com/Prowlarr/Prowlarr)
  - An indexer manager/proxy that supports management of both Torrent trackers and Usenet indexers.
- [Sonarr](https://sonarr.tv/)
  - PVR programs for managing TV Shows. It will automatically monitor your indexers/trackers RSS feeds for new episodes, grab and send the download to a binary newsreader or BitTorrent downloader then rename and organize the resulting download according to your own preferences.
- [Radarr](https://radarr.video/)
  - Same as Sonarr but for Movies.
- [Lidarr](https://lidarr.audio/)
  - Same as Sonarr but for Music.
- [Readarr](https://readarr.com/)
  - Same as Sonarr but for eBooks and Audiobooks.
- [Mylar](https://github.com/mylar3/mylar3)
  - Same as Sonarr but for Comic books and Mangas.
- [Bazarr](https://github.com/morpheus65535/bazarr)
  - Companion application to Sonarr and Radarr, it manages and downloads subtitles based on your requirements.
- [Plex Media Server](https://www.plex.tv/)
  - A centralised media server solution that let you organize your personal video, music as well as photo collections and streams them to all of your devices with a consistent interface.
- [Tautulli](https://tautulli.com/)
  - A 3rd party program that runs alongside a Plex Media Server instance to monitor it's activity and track various statistics that Plex doesn't show in it's own interface.
- [Overseer](https://overseerr.dev/)
  - A program that gives your users the possibility of requesting new media to be added to your instance. Integrates with Plex, Sonarr and Radarr.
- [Calibre](https://calibre-ebook.com/):
  - An eBooks manager that let's you organize your ebooks library, grab metadata from Goodreads and a lot of other cool things.
- [Calibre-Web](https://github.com/janeczku/calibre-web)
  - A web app providing a clean interface for browsing, reading and downloading ebooks from a browser, eReader or mobile application that supports the OPDS protocol.
- [Komga](https://komga.org/)
  - A comic books and mangas media server providing interface for browsing, reading and downloading from a browser, eReader, mobile application that supports the OPDS protocol or Tachiyomi on Android (highly recommended!).
- [Nextcloud](https://nextcloud.com/)
  - A suite of client-server software for creating and using file hosting services. It is functionally similar to Google Drive, although Nextcloud is free and open-source, allowing anyone to self-host an instance.
- [Collabora Online](https://www.collaboraoffice.com/collabora-online/)
  - A powerfull web-based LibreOffice suite that features collaborative editing and which can be integrated in Nextcloud.
- [Tiny Tiny RSS](https://tt-rss.org/)
  - A news feed (RSS/Atom) reader and aggregator.

There's also some "low level" background services:

- [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)
  - A security-enhanced proxy for the docker socket.
- [openvpn-client](https://github.com/dperson/openvpn-client)
  - An OpenVPN client that let's you route other containers traffic through an OpenVPN tunnel.
- [flaresolverr](https://github.com/FlareSolverr/FlareSolverr)
  - A proxy server to bypass Cloudflare protection. Useful if you have trackers that uses Cloudflare protection.
- [unpackerr](https://github.com/davidnewhall/unpackerr)
  - A background program that checks for completed downloads in your BitTorrent downloader and extracts them so Lidarr, Radarr, Readarr, Sonarr may import them.

## Context of my setup

I have a separate server running TrueNAS that host all my files. That's why I'm mounting datasets with NFS on the docker host. On the TrueNAS side all the NFS exports are configured to map all connected machines to a local user that has the necessery rights on the datasets. That way I don't have to deal with UID/GID matching between TrueNAS and the docker host.

## Prerequisites

- Latest Fedora Server release (other Linux distributions are possible but you will need to adapt the setup scripts).
- A properly configured DNS server in your LAN as well as proper DNS entries with a domain suffix for your servers (populated by hand or automatically with the hostname of your devices).
- A paid domain name for which you have full control over.
  - Public DNS records pointing to your public IPv4
    - One subdomain record per service, for exemple `traefik.domain.tld` (you can use a wildcard record but it's not recommended).
    - I personnaly just have one A subdmain record pointing to my router public IPv4 and all the services records are CNAMEs that points to my A subdomain record.
  - [Optional] If you have IPv6 properly configured on your network and your docker host
    - A public AAAA DNS record with the same subdomain name as the IPv4 one.

## Installation

```bash
git clone https://github.com/PlqnK/docker-home-services-host.git
cd docker-home-services-host
for file in *.example*; do cp $file $(echo $file | sed -e 's/.example//'); done
```

If IPv6 is properly configured on your network and your host:

1. Change the `fixed-cidr-v6` CIDR prefix in the `setup/daemon.json` file to a [ULA](https://en.wikipedia.org/wiki/Unique_local_address) prefix (you can generate one here, use your host MAC address <https://www.ip-six.de/>).
2. Change the `NETWORK_xxx_IPV6_PREFIX` variables in the `docker-host-setup.conf` file with your ULA prefix.

If IPv6 is **not** properly configured on your network and/or your host:

1. Comment the line `cp "${SCRIPT_PATH}/daemon.json" /etc/docker/daemon.json` in the `setup/fedora-setup.sh` file.
2. Remove the `--ipv6 --subnet="${NETWORK_xxx_IPV6_PREFIX}"` flags of the `docker network create` commands in the `setup/fedora-setup.sh` file as well.

You then need to:

1. Adapt the NFS mount points in `setup/docker-host-mount-points.txt` with what you have on your file server. You need to make it match the target 1:1, except for the source folder name which isn't important, otherwise you will need to modify every reference to the original target name in the `docker-compose.yml` file.
2. Change the values in the `.env` with ones that fits your environnement.
   - For the `PLEX_CLAIM` variable get a Plex claim token [here](https://www.plex.tv/claim/).
   - For the `TRAEFIK_API_PASSWORD` and `CALIBRE_PASSWORD` variables generate the password hashes as followed:

     ```bash
     openssl passwd -apr1
     ```

   - For the `UNPACKER_xxx_API_KEY` variables you will need to start the stack once, get the API keys from the respective services, update the values and then execute `docker-compose up -d` to recreate the `unpackerr` container with the right configuration.

3. Change the value of the `certificatesResolvers.le.acme.email` variable in the `conf/traefik/traefik.toml` file with your email.
4. Change every reference to `myserver` with the FQDN of the machine that provides the NFS exports in the `setup/docker-host-mount-points.txt` and `setup/docker-host-setup.conf` files.
5. Change the value of the `USER` variable with the name of your administrative user in the `setup/docker-host-setup.conf` file.
6. Put your OpenVPN configuration file(s) in the `conf/openvpn-client` directory.
7. Next, execute the setup script:

   ```bash
   sudo bash setup/fedora-setup.sh
   ```

8. You can then create and run your containers with:

   ```bash
   docker-compose up -d
   ```

## Updating

### Containers

If you just want to update your existing containers execute the following commands:

```bash
cd /path/to/docker-home-services-host
docker-compose pull && docker-compose up -d
```

### Project files

If you want to update the source files of the project in order to get the changes I've made since the last time you cloned/updated the repository you can run a `git pull`.

I **highly** encourage you to read the Merge Requests that have been made to the repository since the last time you updated it. I don't keep a proper changelog so it's the only way to know what has changed and prepare your upgrade accordingly.

## Contributing

Contributions are welcome if you see any area of improvement!

There's no specific guidelines for pull requests but keep in mind that this project is tailored to my needs and, for example, I might not agree with what you think should be added.

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause). A copy of the license is available in this project folder.
