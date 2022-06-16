#!/usr/bin/env bash

if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_PATH="$(cd "${SCRIPT_PATH}/.." &>/dev/null && pwd)" 
readonly SCRIPT_PATH
readonly PROJECT_PATH

# shellcheck source=docker-host-setup.example.conf
source "${SCRIPT_PATH}/docker-host-setup.conf"

# Install standard tools and upstream version of Docker
dnf -y install setools-console htop vim git-core tmux
dnf -y install moby-engine docker-compose

# Enable IPv6 support in docker
cp "${SCRIPT_PATH}/daemon.json" /etc/docker/daemon.json

systemctl enable --now docker
usermod -aG docker "${USER}"

# Configure firewalld
firewalld_default_zone=$(firewall-cmd --get-default-zone)
for service in http https plex; do
  firewall-cmd --permanent --zone="${firewalld_default_zone}" --add-service="${service}"
done
firewall-cmd --permanent --zone="${firewalld_default_zone}" --add-masquerade
firewall-cmd --reload

# Create a docker group and a docker runtime user for a little bit more security
useradd dockerrt -u 3000 -U -M -s /usr/sbin/nologin

# Create the docker networks
docker network create --ipv6 --subnet="${NETWORK_TRAEFIK_IPV6_PREFIX}" traefik-external
docker network create --ipv6 --subnet="${NETWORK_PLEX_IPV6_PREFIX}" plex-external
docker network create --ipv6 --subnet="${NETWORK_WEB_IPV6_PREFIX}" web-egress
docker network create --ipv6 --subnet="${NETWORK_VPN_IPV6_PREFIX}" vpn-tunnel
docker network create --internal socket-proxy
docker network create --internal traefik-internal
docker network create --internal nextcloud-internal
docker network create --internal photoprism-internal
docker network create --internal ttrss-internal

# Configure SELinux to allow the use of OpenVPN in containers
if ! semodule -l | grep docker-openvpn &>/dev/null; then
  dnf -y install checkpolicy
  checkmodule -M -m -o /tmp/docker-openvpn.mod "${SCRIPT_PATH}/docker-openvpn.te"
  semodule_package -o /tmp/docker-openvpn.pp -m /tmp/docker-openvpn.mod
  semodule -i /tmp/docker-openvpn.pp
  echo "tun" > /etc/modules-load.d/tun.conf
  modprobe tun
fi

# Install & setup NFS
dnf -y install nfs-utils autofs
echo "${AUTO_MASTER}" > "/etc/auto.master.d/${STORAGE_SERVER_NAME}.autofs"
cp "${SCRIPT_PATH}/docker-host-mount-points.txt" "/etc/auto.${STORAGE_SERVER_NAME}"
systemctl enable --now autofs

# Configure local storage for containers config, data and runtime files
mkdir -p "${LOCAL_STORAGE}/{config,data,runtime}"

# Copy configs where needed
cp "${PROJECT_PATH}/conf/traefik/traefik.toml" "${PROJECT_PATH}/conf/traefik/traefik-dynamic.toml" "${LOCAL_STORAGE}/config/traefik/"
cp "${PROJECT_PATH}/conf/ttrss/nginx.conf" "${LOCAL_STORAGE}/config/ttrss/"
cp -r "${PROJECT_PATH}/conf/openvpn-client/." "${LOCAL_STORAGE}/config/openvpn-client/"

# Create traefik acme.json file if it doesn't exists
touch "${LOCAL_STORAGE}/data/traefik/acme.json" && chmod 600 "${LOCAL_STORAGE}/data/traefik/acme.json"
