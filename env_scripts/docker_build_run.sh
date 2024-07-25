#!/bin/bash
# DIR is the directory where the script is saved (should be <project_root/scripts)
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
cd $DIR

MY_UID=$(id -u)
MY_GID=$(id -g)
MY_UNAME=$(id -un)
# base image: pytorch built on cuda 12.2
BASE_IMAGE=nvcr.io/nvidia/pytorch:23.10-py3
mkdir -p ${DIR}/.vscode-server
LINK=$(realpath --relative-to="/home/${MY_UNAME}" "$DIR" -s)
IMAGE=pareval
if [ -z "$(docker images -q ${IMAGE})" ]; then
    # Create dev.dockerfile
    FILE=dev.dockerfile

    ### Pick Tensorflow / Torch based base image below
    # echo "FROM nvcr.io/nvidia/tensorflow:23.01-tf2-py3" > $FILE
    echo "FROM $BASE_IMAGE" > $FILE

    echo "  RUN apt-get update" >> $FILE
    echo "  RUN apt-get -y install nano gdb time" >> $FILE
    # echo "  RUN apt-get -y install nvidia-cuda-gdb" >> $FILE
    echo "  RUN apt-get -y install sudo" >> $FILE
    echo "  RUN (groupadd -g $MY_GID $MY_UNAME || true) && useradd --uid $MY_UID -g $MY_GID --no-log-init --create-home $MY_UNAME && (echo \"${MY_UNAME}:password\" | chpasswd) && (echo \"${MY_UNAME} ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers)" >> $FILE

    echo "  RUN mkdir -p $DIR" >> $FILE
    echo "  RUN ln -s ${LINK}/.vscode-server /home/${MY_UNAME}/.vscode-server" >> $FILE
    echo "  RUN echo \"fs.inotify.max_user_watches=524288\" >> /etc/sysctl.conf" >> $FILE
    echo "  RUN sysctl -p" >> $FILE
    echo "  USER $MY_UNAME" >> $FILE
    
    echo "  COPY docker.bashrc /home/${MY_UNAME}/.bashrc" >> $FILE     
    echo "  RUN source /home/${MY_UNAME}/.bashrc" >> $FILE
    # echo "  COPY requirements.txt /home/${MY_UNAME}/pareval_req.txt" >> $FILE
   # START: install any additional package required for your image here
    # echo "  RUN pip install -r /home/${MY_UNAME}/pareval_req.txt" >> $FILE 
    echo "  RUN pip install datasets transformers huggingface-hub accelerate bitsandbytes peft pynvml tensorboard google-generativeai
" >> $FILE
    echo "  ENV HF_HOME='/home/${MY_UNAME}/.cache/huggingface'" >> $FILE
    # END: install any additional package required for your image here
    echo "  ENV PATH='/home/${MY_UNAME}/.local/bin:${PATH}'"
    # echo "  ENV PYTHONPATH='/home/${MY_UNAME}/.local/lib/python3.10/site-packages:${PYTHONPATH}'"
    echo "  WORKDIR $DIR/.." >> $FILE
    echo "  CMD /bin/bash" >> $FILE

    docker buildx build -f dev.dockerfile -t ${IMAGE} .
fi
# map the .cache of the scratch into the .cache in the container
CACHE_FOLDER_ON_HOST=/home/${MY_UNAME}/scratch/.cache/
MOUNT_CACHE_FOLDER=" --mount type=bind,source=${CACHE_FOLDER_ON_HOST},target=/home/${MY_UNAME}/.cache"
# map the code folder into the same path in the container (both are on the scratch)
CODE_FOLDER=/home/${MY_UNAME}/code
MOUNT_CODE_FOLDER=" --mount type=bind,source=${CODE_FOLDER},target=${CODE_FOLDER}"
# map the data folder into the same path in the container (both are on the scratch)
DATA_FOLDER=/home/${MY_UNAME}/data
MOUNT_DATA_FOLDER=" --mount type=bind,source=${DATA_FOLDER},target=${DATA_FOLDER}"


EXTRA_MOUNTS=""
if [ -d "/home/${MY_UNAME}/scratch/" ]; then
# running on the cluster or lws - mount the whole scratch
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/scratch,target=/home/${MY_UNAME}/scratch"
else
# other machine. assume it has the following folders in place:
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/code,target=/home/${MY_UNAME}/code"
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/data,target=/home/${MY_UNAME}/data"
    EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/models,target=/home/${MY_UNAME}/models"
    # EXTRA_MOUNTS+=" --mount type=bind,source=/home/${MY_UNAME}/.cache/huggingface,target=/home/${MY_UNAME}/.cache/huggingface"
fi



docker run \
    --gpus \"device=all\" \
    --privileged \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 -it --rm \
    ${MOUNT_CODE_FOLDER} \
    ${MOUNT_DATA_FOLDER} \
    ${MOUNT_CACHE_FOLDER} \
    --shm-size=8g \
    --name pareval  \
    ${IMAGE}

    # --mount type=bind,source=/home/scratch.svc_compute_arch,target=/home/scratch.svc_compute_arch \
    # --mount type=bind,source=/home/utils,target=/home/utils \
    # --mount type=bind,source=/home/scratch.computelab,target=/home/scratch.computelab \
    # --name nemo \
    # -p 8888:8888 -p 6006:6006 
    # --mount type=bind,source=${DIR}/..,target=${DIR}/.. \
    # --mount type=bind,source=/home/${MY_UNAME}/.cache,target=/home/${MY_UNAME}/.cache \

    # ${EXTRA_MOUNTS} \
cd -
