#!/bin/bash

if [ ! -f /root/.ssh/id_rsa ]; then
	ssh-keygen -q -t rsa -f /root/.ssh/id_rsa -N ""
fi
cat >/root/.ssh/config <<EOF
Host *
    StrictHostKeyChecking no
EOF
ssh-copy-id root@$1
scp Linux_check.sh root@$1:/tmp/
ssh root@$1 'chmod +x /tmp/Linux_check.sh;bash /tmp/Linux_check.sh'
scp -r root@$1:/tmp/sysssc/* .
ssh root@$1 "sed -i '\$d' .ssh/authorized_keys;rm -rf /tmp/sysssc;rm -f /tmp/Linux_check.sh"

exit 0