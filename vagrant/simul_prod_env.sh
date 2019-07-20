#!/usr/bin/env bash

readonly EXPORT_ROOT="/srv/nfs"
readonly EXPORT_DIRS="${EXPORT_ROOT}/cloud/data ${EXPORT_ROOT}/downloads/bittorrent/{leeching,seeding,watching} \
${EXPORT_ROOT}/downloads/usenet/{completed,processing,watching} \
${EXPORT_ROOT}/medias/{audio_drama,audiobooks,books,comics,movies,music,podcasts,test_videos,tv_shows} \
${EXPORT_ROOT}/sync/vagrant/{documents,pictures,videos}"

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
chown 80:80 ${EXPORT_ROOT}/cloud/data && chmod 750 ${EXPORT_ROOT}/cloud/data
chown root:1004 ${EXPORT_ROOT}/downloads/bittorrent/* && chmod 770 ${EXPORT_ROOT}/downloads/bittorrent/*
chown root:1004 ${EXPORT_ROOT}/downloads/usenet/* && chmod 770 ${EXPORT_ROOT}/downloads/usenet/*
chown root:1005 ${EXPORT_ROOT}/medias/* && chmod 775 ${EXPORT_ROOT}/medias/*
chown 1000:1001 ${EXPORT_ROOT}/sync/vagrant/* && chmod 755 ${EXPORT_ROOT}/sync/vagrant/*
cat << EOF > /etc/exports
${EXPORT_ROOT}/cloud/data localhost(rw,all_squash,anonuid=80,anongid=80)
${EXPORT_ROOT}/downloads/bittorrent/leeching localhost(rw,all_squash,anonuid=65534,anongid=1004)
${EXPORT_ROOT}/downloads/bittorrent/seeding localhost(rw,all_squash,anonuid=65534,anongid=1004)
${EXPORT_ROOT}/downloads/bittorrent/watching localhost(rw,all_squash,anonuid=65534,anongid=1004)
${EXPORT_ROOT}/downloads/usenet/completed localhost(rw,all_squash,anonuid=65534,anongid=1004)
${EXPORT_ROOT}/downloads/usenet/processing localhost(rw,all_squash,anonuid=65534,anongid=1004)
${EXPORT_ROOT}/downloads/usenet/watching localhost(rw,all_squash,anonuid=65534,anongid=1004)
${EXPORT_ROOT}/medias/audio_drama localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/audiobooks localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/books localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/comics localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/movies localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/music localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/podcasts localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/test_videos localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/medias/tv_shows localhost(rw,all_squash,anonuid=65534,anongid=1005)
${EXPORT_ROOT}/sync/vagrant/documents localhost(rw,all_squash,anonuid=1000,anongid=1001)
${EXPORT_ROOT}/sync/vagrant/pictures localhost(rw,all_squash,anonuid=1000,anongid=1001)
${EXPORT_ROOT}/sync/vagrant/videos localhost(rw,all_squash,anonuid=1000,anongid=1001)
EOF
restorecon /etc/exports
systemctl restart nfs-server
mkdir -p /opt/rsync
echo "vagrant" > /opt/rsync/rsync_password
chmod 0640 /opt/rsync/rsync_password
cat << EOF > /opt/rsync/docker_backup.sh
#!/usr/bin/env bash

/usr/bin/rsync -avz vagrant@localhost::docker_backup /opt/rsync/docker_backup --password-file /opt/rsync/rsync_password
EOF
chmod +x /opt/rsync/docker_backup.sh
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
ExecStart=/opt/rsync/docker_backup.sh
EOF
systemctl enable --now docker-backup.timer
