#!/usr/bin/env bash

readonly EXPORT_ROOT="/srv/nfs"
readonly EXPORT_DIRS="${EXPORT_ROOT}/cloud/data ${EXPORT_ROOT}/downloads/bittorrent/{leeching,seeding,watching} \
${EXPORT_ROOT}/downloads/usenet/{completed,processing,watching} \
${EXPORT_ROOT}/medias/{audio_drama,audiobooks,books,comics,movies,music,podcasts,tv_shows} ${EXPORT_ROOT}/sync"

yum upgrade -y
yum install -y firewalld nfs-utils rpcbind rsync
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=nfs3
firewall-cmd --reload
systemctl enable --now rpcbind nfs-server
# I know, eval is evil. But this is the only way to have variable expansion before the brace expansion so that
# "mkdir {folder1,folder2}" creates 2 folders instead of 1 folder named litteraly "{folder1,folder2}".
eval "mkdir -p ${EXPORT_DIRS}"
cat << EOF > /etc/exports
${EXPORT_ROOT}/cloud/data localhost(rw)
${EXPORT_ROOT}/downloads/bittorrent/leeching localhost(rw)
${EXPORT_ROOT}/downloads/bittorrent/seeding localhost(rw)
${EXPORT_ROOT}/downloads/bittorrent/watching localhost(rw)
${EXPORT_ROOT}/downloads/usenet/completed localhost(rw)
${EXPORT_ROOT}/downloads/usenet/processing localhost(rw)
${EXPORT_ROOT}/downloads/usenet/watching localhost(rw)
${EXPORT_ROOT}/medias/audio_drama localhost(rw)
${EXPORT_ROOT}/medias/audiobooks localhost(rw)
${EXPORT_ROOT}/medias/books localhost(rw)
${EXPORT_ROOT}/medias/comics localhost(rw)
${EXPORT_ROOT}/medias/movies localhost(rw)
${EXPORT_ROOT}/medias/music localhost(rw)
${EXPORT_ROOT}/medias/podcasts localhost(rw)
${EXPORT_ROOT}/medias/tv_shows localhost(rw)
${EXPORT_ROOT}/sync localhost(rw)
EOF
restorecon /etc/exports
systemctl restart nfs-server
mkdir -p /opt/rsync
echo "vagrant" > /opt/rsync/rsync_password
chmod 0640 /opt/rsync/rsync_password
cat << EOF > /etc/systemd/system/docker-backup.timer
[Unit]
Description=Backup docker data every 10 min

[Timer]
OnCalendar=*:0/10
Persistent=false

[Install]
WantedBy=timers.target
EOF
cat << EOF > /etc/systemd/system/docker-backup.service
[Unit]
Description=Backup docker data

[Service]
ExecStart=/usr/bin/rsync -avz vagrant@localhost::docker_backup /opt/rsync/docker_backup --password-file /opt/rsync/rsync_password
EOF
systemctl enable --now docker-backup.timer
