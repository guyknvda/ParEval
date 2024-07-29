FROM nvcr.io/nvidia/pytorch:23.10-py3
  RUN apt-get update
  RUN apt-get -y install nano gdb time
  RUN apt-get -y install sudo
  RUN (groupadd -g 30 gkoren || true) && useradd --uid 90013 -g 30 --no-log-init --create-home gkoren && (echo "gkoren:password" | chpasswd) && (echo "gkoren ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers)
  RUN mkdir -p /home/gkoren/code/github/guyknvda/ParEval/env_scripts
  RUN ln -s code/github/guyknvda/ParEval/env_scripts/.vscode-server /home/gkoren/.vscode-server
  RUN echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
  RUN sysctl -p
  USER gkoren
  COPY docker.bashrc /home/gkoren/.bashrc
  RUN source /home/gkoren/.bashrc
  RUN pip install datasets transformers huggingface-hub accelerate bitsandbytes peft pynvml tensorboard google-generativeai

  ENV HF_HOME='/home/gkoren/.cache/huggingface'
  WORKDIR /home/gkoren/code/github/guyknvda/ParEval/env_scripts/..
  CMD /bin/bash
