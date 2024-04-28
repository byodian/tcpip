# TCPIP

## 步骤

1. 创建虚拟机，可以为一台虚拟机设置多个网卡，比如 NAT、桥接网络等

2. 安装 Docker
   [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

   或者使用脚本 [install_docker.sh](./install_docker.sh)

   ```
   chmod +x ./install_docker.sh
   ./install_docker.sh
   ```
4. Open vSwitch
   
   ```bash
   apt-get -y install openvswitch-common openvswitch-dbg openvswitch-switch python-openvswitch openvswitch-ipsec openvswitch-pki openvswitch-vtep
   apt-get -y install bridge-utils
   apt-get -y install arping
   ```

5. 准备 SSH Server 镜像 [Dockerfile](./docker/Dockefile)
   ```Dockerfile
   FROM ubuntu:22.04
    
   # 安装 OpenSSH 服务器、网络工具
   RUN apt-get -y update && apt-get install -y iproute2 iputils-arping net-tools tcpdump curl telnet iputils-tracepath traceroute openssh-server iputils-ping
    
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
   ```

6. 配置虚拟机网络包转发功能
   ```bash
   echo 1 > /proc/sys/net/ipv4/ip_forward
   sysctl -p
   /sbin/iptables -P FORWARD ACCEPT
   ````
  - /proc/sys/net/ipv4/ip_forward 值为1时，启用 IP 转发功能，Linux 主机将转发经过它的包，而不仅仅是处理发往自己的包。
  
  - iptables 的 FORWARD 链默认策略设置为 ACCEPT，这意味着 Linux 主机将允许所有需要转发的数据包通过。在配置 Linux 主机作为网络路由器时，必须确保 FORWARD 链的默认策略是 ACCEPT，以确保它可以正确转发数据包。iptables 有三个主要的默认策略链：
    - INPUT：处理目标地址是本机的数据包。
    - OUTPUT：处理源地址是本机的数据包。
    - FORWARD：处理需要转发的数据包（即不是发往本机或来自本机的数据包）。
      sysctl -p 加载 sysctl 配置文件使其生效，在这里它确保之前设置的 IP 这发功能立即生效。sysctl -p 命令会重新加载所有在 /etc/sysctl.conf 中定义的内核参数，包括 IP 转发。
      sysctl 是一个 Linux 命令，用于在运行时修改内核参数。它允许你查看、设置和调整内核运行的各种参数。这些参数可以影响系统的性能、网络、安全性等方面。

5. 启动环境，使用脚本 [setupenv.sh](./setupenv.sh)
   ```bash
   git clone https://github.com/byodian/tcpip.git
   cd tcpip
   docker build -f ./docker/Dockerfile -t ssh_server:tcpip ./docker
   chmod +x setupenv.sh
   ./setupenv.sh ens33 ssh_server:tcpip # ens33 虚拟机网卡名称
   ```
## 网络拓扑图

setupenv.sh 脚本启动的网络拓扑图

<img width="632" alt="网络拓扑图" src="https://github.com/byodian/tcpip/assets/26178657/fee74527-f864-42b6-8297-09d4e927001d">

