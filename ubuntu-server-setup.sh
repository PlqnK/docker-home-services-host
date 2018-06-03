#!/usr/bin/env bash

if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

source docker-host-setup.conf

# Install Docker
apt-get update && apt-get upgrade -y
apt-get install -y apt-transport-https ca-certificates software-properties-common htop wget curl nano vim git
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update && apt-get install -y docker-ce docker-compose
usermod -aG docker "${USER}"

# Create a docker group and a docker runtime user for a little bit more security
useradd dockerrt -d /nonexistent -u 1001 -U -s /usr/sbin/nologin

# Install & setup NFS
apt-get install -y nfs-common autofs
mkdir -p "${MOUNT_POINT_DIRS}"
echo "${AUTO_MASTER}" >> /etc/auto.master
cp docker-host-mount-points.txt /etc/auto."${STORAGE_SERVER_NAME}"
systemctl enable autofs && systemctl start autofs

# Configure local storage and rsync for config files
mkdir -p "${LOCAL_STORAGE_DIRS}"
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}" && chmod -R 755 "${LOCAL_STORAGE}"
sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync
cp docker-host-rsyncd.conf /etc/rsyncd.conf && cp docker-host-rsyncd.secrets /etc/rsyncd.secrets
chmod 600 /etc/rsyncd.secrets
systemctl enable rsync.service && systemctl start rsync.service

# Copy configs where needed
cp traefik.toml "${LOCAL_STORAGE}"/traefik/config/traefik.toml
touch "${LOCAL_STORAGE}"/traefik/config/acme.json && chmod 600 "${LOCAL_STORAGE}"/traefik/config/acme.json
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}"/traefik/config && chmod 755 "${LOCAL_STORAGE}"/traefik/config/traefik.toml

if [[ -f custom.ovpn ]]; then
  cp custom.ovpn "${LOCAL_STORAGE}"/transmission/openvpn/custom.ovpn
  chown dockerrt:dockerrt "${LOCAL_STORAGE}"/transmission/openvpn/custom.ovpn
  chmod 600 "${LOCAL_STORAGE}"/transmission/openvpn/custom.ovpn
fi
