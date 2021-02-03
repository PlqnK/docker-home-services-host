#!/usr/bin/env bash

if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

# shellcheck source=docker-host-setup.example.conf
source docker-host-setup.conf

# Install standard tools and upstream version of Docker
dnf -y upgrade
dnf -y install dnf-plugins-core setools-console rsync htop wget curl nano vim git
dnf -y install moby-engine docker-compose
systemctl enable --now docker
usermod -aG docker "${USER}"

# Configure firewalld
# Docker doesn't play well with nftables for now (december 2020), so we change the firewalld backend to iptables.
# You can keep the nftables backend as long as you enable masquerading on the default firewalld interface. But doing so
# messes with the origin IP addresses of all requests. Traefik for example will see all the requests coming from
# the IP address of the docker bridge (something like 172.19.0.1) instead of the real one. So it will set the headers
# "X-Forwarded-For" and "X-Real-IP" to the IP of the docker bridge which is less than ideal if you want to configure
# external bandwidth restrictions in Plex for example.
sed -i 's/^FirewallBackend=nftables/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf
systemctl restart firewalld
firewalld_default_zone=$(firewall-cmd --get-default-zone)
for service in http https plex; do
  firewall-cmd --permanent --zone="${firewalld_default_zone}" --add-service="${service}"
done
firewall-cmd --reload

# Create a docker group and a docker runtime user for a little bit more security
useradd dockerrt -d /nonexistent -u 3000 -U -s /usr/sbin/nologin

# Create the docker networks
docker network create --internal internal
docker network create --internal socket-proxy
docker network create web-proxy
docker network create vpn

# Configure SELinux to allow the use of OpenVPN in containers
if ! semodule -l | grep docker-openvpn &>/dev/null; then
  dnf -y install checkpolicy
  checkmodule -M -m -o /tmp/docker-openvpn.mod docker-openvpn.te
  semodule_package -o /tmp/docker-openvpn.pp -m /tmp/docker-openvpn.mod
  semodule -i /tmp/docker-openvpn.pp
  echo "tun" > /etc/modules-load.d/tun.conf
  modprobe tun
fi

# Install & setup NFS
dnf -y install nfs-utils autofs
echo "${AUTO_MASTER}" > /etc/auto.master.d/"${STORAGE_SERVER_NAME}".autofs
cp docker-host-mount-points.txt /etc/auto."${STORAGE_SERVER_NAME}"
systemctl enable --now autofs

# Configure local storage for config files
eval "mkdir -p ${LOCAL_STORAGE_DIRS}"
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}" && chmod -R 755 "${LOCAL_STORAGE}"

# Copy configs where needed
cp traefik.toml traefik-dynamic.toml "${LOCAL_STORAGE}"/traefik/config/
touch "${LOCAL_STORAGE}"/traefik/config/acme.json && chmod 600 "${LOCAL_STORAGE}"/traefik/config/acme.json
chown -R dockerrt:dockerrt "${LOCAL_STORAGE}"/traefik/config

if [[ -f custom.ovpn ]]; then
  cp client.ovpn "${LOCAL_STORAGE}"/openvpn-client/config/client.ovpn
  chown dockerrt:dockerrt "${LOCAL_STORAGE}"/openvpn-client/config/client.ovpn
  chmod 600 "${LOCAL_STORAGE}"/openvpn-client/config/client.ovpn
fi
