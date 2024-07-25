#!/bin/bash
# DIR is the directory where the script is saved (should be <project_root/scripts)
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd $DIR

MY_UNAME=$(id -un)
IMAGE=pareval:dev

# map the .cache of the scratch into the .cache in the container
CACHE_FOLDER_ON_HOST=/home/${MY_UNAME}/scratch/.cache/
MOUNT_CACHE_FOLDER=" --mount type=bind,source=${CACHE_FOLDER_ON_HOST},target=/home/${MY_UNAME}/.cache"
# map the code folder into the same path in the container (both are on the scratch)
CODE_FOLDER=/home/${MY_UNAME}/code
MOUNT_CODE_FOLDER=" --mount type=bind,source=${CODE_FOLDER},target=${CODE_FOLDER}"
# map the data folder into the same path in the container (both are on the scratch)
DATA_FOLDER=/home/${MY_UNAME}/data
MOUNT_DATA_FOLDER=" --mount type=bind,source=${DATA_FOLDER},target=${DATA_FOLDER}"


docker run \
    --gpus \"device=all\" \
    --privileged \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 -it --rm \
    ${MOUNT_CODE_FOLDER} \
    ${MOUNT_DATA_FOLDER} \
    ${MOUNT_CACHE_FOLDER} \
    --shm-size=8g \
    --name pareval -p 8888:8888 -p 6006:6006 \
    ${IMAGE}

cd -