#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true

groups:
    - ubuntu
    - docker
sudo:
    - ALL=(ALL) NOPASSWD:ALL

packages:
  - curl
  - apt-transport-https
  - ca-certificates
  - software-properties-common
  - gnupg-agent
runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - apt-get install -y docker-compose
  - systemctl start docker
  - systemctl enable docker
  - docker run -d --restart always -p 80:5000 bencuk/python-demoapp
  - docker run -d --restart always -p 81:5000 bencuk/python-demoapp