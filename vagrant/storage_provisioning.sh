#!/usr/bin/env bash

OLDIFS=$IFS; IFS=','
for group in cloud,2002 downloads,2003 medias,2004; do
  set -- $group
  if [[ ! $(getent group $1) ]]; then
    pw groupadd $1 -g $2
  fi
done
IFS=$OLDIFS

OLDIFS=$IFS; IFS=','
for path in cloud/data,33:33,0750 downloads/bittorrent,root:downloads,0775 downloads/usenet,root:downloads,0775 medias/audiobooks,root:medias,0775 medias/audiodrama,root:medias,0775 medias/books,root:medias,0775 medias/comics,root:medias,0775 medias/movies,root:medias,0775 medias/music,root:medias,0775 medias/series,root:medias,0775; do
  set -- $path
  if [[ ! -d "/mnt/vault/${1}" ]]; then
    mkdir -p "/srv/vault/${1}"
    mkdir -p "/mnt/vault/${1}"
    chown "${2}" "/srv/vault/${1}"
    chmod "${3}" "/srv/vault/${1}"
    mount -t nullfs "/srv/vault/${1}" "/mnt/vault/${1}"
    echo "/srv/vault/${1} /mnt/vault/${1} nullfs rw 0 0" >> /etc/fstab
  fi
done
IFS=$OLDIFS

cat <<-EOF > /etc/exports
V4: / -sec=sys
/mnt/vault/cloud/data -mapall=33:33 media.localdomain
/mnt/vault/downloads/bittorrent -mapall="nobody":"downloads" media.localdomain
/mnt/vault/downloads/usenet -mapall="nobody":"downloads" media.localdomain
/mnt/vault/medias/audiobooks -mapall="nobody":"medias" media.localdomain
/mnt/vault/medias/audiodrama -mapall="nobody":"medias" media.localdomain
/mnt/vault/medias/books -mapall="nobody":"medias" media.localdomain
/mnt/vault/medias/comics -mapall="nobody":"medias" media.localdomain
/mnt/vault/medias/movies -mapall="nobody":"medias" media.localdomain
/mnt/vault/medias/music -mapall="nobody":"medias" media.localdomain
/mnt/vault/medias/series -mapall="nobody":"medias" media.localdomain
EOF

for rc_option in rpcbind_enable="YES" nfs_server_enable="YES" mountd_enable="YES" nfsv4_server_enable="YES" nfsuserd_enable="YES"; do
  if [[ ! $(grep "${rc_option}" /etc/rc.conf) ]]; then
    echo "${rc_option}" >> /etc/rc.conf
  fi
done

service nfsd start
service mountd reload
