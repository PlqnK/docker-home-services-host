#!/usr/bin/env bash

set -e

if [[ ${EUID} -ne 0 ]]; then
  echo "Must be executed as root." 1>&2
  exit 1
fi

echo "Removing images which have a more recent tag"

for image in $(podman image ls --format "{{.Repository}} {{.Tag}}" | grep -v "<none>" | sort | awk '{print $1}' | uniq -d); do
  podman image rm -f $(podman image ls --format "{{.Repository}}:{{.Tag}}" "${image}" | sort | head -n -1 | tr '\n' ' ');
done
