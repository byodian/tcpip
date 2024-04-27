FROM ubuntu:22.04

# 安装 OpenSSH 服务器
RUN apt-get -y update && apt-get install -y iproute2 iputils-arping net-tools tcpdump curl telnet iputils-tracepath traceroute openssh-server

# 创建 SSH 服务器所需的目录
RUN mkdir /var/run/sshd

# 设置 root 密码
RUN echo 'root:1212' | chpasswd

# 允许 root 用户登录
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 允许通过密码登录
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 设置 LANG 环境变量，避免 SSH 登录时出现警告信息
ENV LANG C.UTF-8

# 指定容器启动时执行的命令
ENTRYPOINT ["/usr/sbin/sshd", "-D"]

