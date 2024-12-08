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

REPO=ghcr.io/kaist-ina/stellatrain:main
docker pull $REPO

# Run
sudo docker run -itd --rm --gpus all --ipc=host --net=host --ulimit memlock=-1 --ulimit stack=67108864 $REPO \
  /bin/bash -c "./test_script.sh --master-ip-address $MASTER_IP --my-ip-address $MY_IP --world-size $WORLD_SIZE --num-gpus $NUM_GPUS --rank $RANK"