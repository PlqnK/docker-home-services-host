#!/usr/bin/env bash

set -e

if [[ ${EUID} -ne 0 ]]; then
  echo "Must be executed as root." 1>&2
  exit 1
fi

echo "Pulling new images"

for image in $(grep -s -h -r "Image=" /etc/containers/systemd/ /etc/systemd/system/ | awk -F= '{print $2}' | uniq); do
  podman image pull "${image}"
done
