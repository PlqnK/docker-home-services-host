#!/usr/bin/env bash

# Make sure that we are running as root
if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

# Source variables from config file
source docker-host-setup.conf

# Install Docker
dnf -y upgrade
dnf -y install dnf-plugins-core htop wget curl nano vim git
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf -y upgrade && dnf -y install docker-ce docker-compose
systemctl enable docker && systemctl start docker
usermod -aG docker "${USER}"

# Create a docker group and a docker runtime user for a little bit more security
useradd dockerrt -d /nonexistent -u 1001 -U -s /usr/sbin/nologin

# Install & setup NFS
dnf -y install nfs-utils autofs
mkdir -p "${MOUNT_POINT_DIRS}"
echo "${AUTO_MASTER}" > /etc/auto.master.d/chappie.autofs
cp docker-host-mount-points.txt /etc/auto."${STORAGE_SERVER_NAME}"
systemctl enable autofs && systemctl start autofs

# Configure local storage and rsync for config files
mkdir -p "${LOCAL_STORAGE_DIRS}"
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}" && chmod -R 755 "${LOCAL_STORAGE}"
cp docker-host-rsyncd.conf /etc/rsyncd.conf && cp docker-host-rsyncd.secrets /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets
systemctl enable rsyncd.service && systemctl start rsyncd.service

# Copy Traefik config
cp traefik.toml "${LOCAL_STORAGE}"/traefik/config/traefik.toml
touch "${LOCAL_STORAGE}"/traefik/config/acme.json && chmod 600 "${LOCAL_STORAGE}"/traefik/config/acme.json
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}"/traefik/config && chmod 755 "${LOCAL_STORAGE}"/traefik/config/traefik.toml