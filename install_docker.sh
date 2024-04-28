#!/bin/bash

COLOR_SUCC="\e[92m"
COLOR_NONE="\e[0m"
COLOR_ERROR="\e[38;5;198m"

install_docker () {
    if ! [ -x "$(command -v docker)"]; then
        # Set up the repository
        sudo apt-get update
        sudo apt-get -y install \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
            
        # Add Docker’s official GPG key:
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Use the following command to set up the repository:
        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo docker run hello-world
    else
        echo -e "${COLOR_SUCC}DOCKER CE 已经安装成功了 ${COLOR_NONE}"
    fi
}
