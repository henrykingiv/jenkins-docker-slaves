locals { 
    docker-userdata = <<-EOF
#!/bin/bash 
sudo -i
#install docker
apt update
apt install gnupg2 pass -y
apt install docker.io -y
#ser to Docker group
usermod -aG docker $USER
newgrp docker
hostnamectl set-hostname Docker

#to run at startup
systemctl start docker
systemctl enable docker
systemctl status docker
sed -i 's|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:4243|' /lib/systemd/system/docker.service

#sed -i -e '14aExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:4243' -e '14d' /lib/systemd/system/docker.service
chmod 666 /var/run/docker.sock

systemctl daemon-reload
service docker restart
git clone https://github.com/henrykingiv/docker-jenkins-slave.git; cd docker-jenkins-slave
docker build -t my-jenkins-slave .
EOF
}