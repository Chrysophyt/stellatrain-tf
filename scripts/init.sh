#!/bin/bash

# Start the application
export MASTER_IP="${master_ip}"
export MY_IP="${my_ip}"
export WORLD_SIZE="${world_size}"
export NUM_GPUS="${num_gpus}"
export RANK="${rank}"

bash -c 'echo $MASTER_IP'
bash -c 'echo $MY_IP'
bash -c 'echo $WORLD_SIZE'
bash -c 'echo $NUM_GPUS'
bash -c 'echo $RANK'

# Install Docker

## Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

## Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update


sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Install NVIDIA Driver
wget http://us.download.nvidia.com/tesla/470.256.02/NVIDIA-Linux-x86_64-470.256.02.run
sudo apt-get install gcc -y
sudo apt-get install make -y

sudo sh ./NVIDIA-Linux-x86_64-470.256.02.run --no-drm --disable-nouveau --silent --install-libglvnd

## Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
&& sudo apt-get update

sudo apt-get install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=docker

sudo systemctl restart docker

# Pull Image
REPO=ghcr.io/kaist-ina/stellatrain:main
sudo docker pull $REPO

# Run
sudo docker run -itd --rm --gpus all --ipc=host --net=host --ulimit memlock=-1 --ulimit stack=67108864 $REPO
