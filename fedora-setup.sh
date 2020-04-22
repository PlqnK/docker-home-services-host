#!/usr/bin/env bash

if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

source docker-host-setup.conf

# Install standard tools and upstream version of Docker
dnf -y upgrade
dnf -y install dnf-plugins-core rsync htop wget curl nano vim git
dnf -y install moby-engine docker-compose
systemctl enable --now docker
usermod -aG docker "${USER}"

# Configure firewalld to work with docker (allow inter-container communication on port 443)
# See here for more information: https://opsech.io/posts/2017/May/23/docker-dns-with-firewalld-on-fedora.html
firewall-cmd --permanent --new-zone=docker
firewall-cmd --permanent --zone=docker --add-interface=docker0
firewall-cmd --permanent --zone=docker --add-source=172.16.0.0/12
firewall-cmd --permanent --zone=docker --add-service=https
firewall-cmd --reload
systemctl restart docker

# Create a docker group and a docker runtime user for a little bit more security
useradd dockerrt -d /nonexistent -u 3000 -U -s /usr/sbin/nologin

# Create the docker networks
docker network create proxy
docker network create internal

# Install & setup NFS
dnf -y install nfs-utils autofs
# I know, eval is evil. But this isn't a mission critical command and this is the only way to have variable expansion
# before the brace expansion so that "mkdir {folder1,folder2}" creates 2 folders instead of 1 folder named litteraly
# "{folder1,folder2}"
eval "mkdir -p ${MOUNT_POINT_DIRS}"
echo "${AUTO_MASTER}" > /etc/auto.master.d/"${STORAGE_SERVER_NAME}".autofs
cp docker-host-mount-points.txt /etc/auto."${STORAGE_SERVER_NAME}"
systemctl enable --now autofs

# Configure local storage for config files
eval "mkdir -p ${LOCAL_STORAGE_DIRS}"
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}" && chmod -R 755 "${LOCAL_STORAGE}"

# Copy configs where needed
cp traefik.toml "${LOCAL_STORAGE}"/traefik/config/traefik.toml
touch "${LOCAL_STORAGE}"/traefik/config/acme.json && chmod 600 "${LOCAL_STORAGE}"/traefik/config/acme.json
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}"/traefik/config && chmod 755 "${LOCAL_STORAGE}"/traefik/config/traefik.toml

if [[ -f custom.ovpn ]]; then
  cp custom.ovpn "${LOCAL_STORAGE}"/transmission/openvpn/custom.ovpn
  chown dockerrt:dockerrt "${LOCAL_STORAGE}"/transmission/openvpn/custom.ovpn
  chmod 600 "${LOCAL_STORAGE}"/transmission/openvpn/custom.ovpn
fi
