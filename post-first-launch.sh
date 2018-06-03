#!/usr/bin/env bash

if [[ "$(id -u)" -ne "0" ]]; then
  echo "Script must be ran as root."
  exit
fi

source .env && source docker-host-setup.conf

# Enable access to SABnzbd
sed -i "s/host_whitelist = .*/host_whitelist = sabnzbd.${DOMAIN_NAME},/g" "${LOCAL_STORAGE}"/sabnzbd/config/sabnzbd.ini
