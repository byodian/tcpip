#!/bin/bash

set -e

publiceth=$1
imagename=$2

delete_container () {
	container_name="$1"
	if docker ps -a --format '{{.Names}}' | grep -q "$container_name"; then
		docker rm -f "$container_name"
	else
		echo "容器 $container_name 不存在，无需删除"
	fi

}

delete_network() {
	network_name="$1"
	if ip link show | grep -q "$network_name"; then
		ip link delete dev "$network_name"
	else
		echo "网络 $network_name 不存在，无需删除。"
	fi
}

delete_br() {
	br_name="$1"
	if ovs-vsctl list-br | grep -q "$br_name"; then
		ovs-vsctl del-br "$br_name"
	else
		echo "网桥 $br_name 不存在，无需删除。"
	fi

}

containers=("aix" "solaris" "gemini" "gateway" "netb" "sun" "svr4" "bsdi" "slip")
networks=("slipside" "bsdiside" "netbside" "sunside" "gatewayin" "gatewayout")
bridges=("net1" "net2")

for container_name in "${containers[@]}"; do
	delete_container $container_name
done

for network in "${network[@]}"; do
	delete_network $network
done

for bridge in "${bridges[@]}"; do
	delete_br $bridge
done

echo "create all containers"
docker run --privileged --network none --name aix -d ${imagename}
docker run --privileged --network none --name solaris -d ${imagename}
docker run --privileged --network none --name gemini -d ${imagename}
docker run --privileged --network none --name gateway -d ${imagename}
docker run --privileged --network none --name netb -d ${imagename}
docker run --privileged --network none --name sun -d ${imagename}
docker run --privileged --network none --name svr4 -d ${imagename}
docker run --privileged --network none --name bsdi -d ${imagename}
docker run --privileged --network none --name slip -d ${imagename}

# 创建两个网桥，代表两个二层网络
ovs-vsctl add-br net1
ip link set net1 up
ovs-vsctl add-br net2
ip link set net2 up
#将所有的节点连接到两个网络
echo "connect all containers to bridges"

chmod +x ./pipework

./pipework net1 aix 140.252.1.92/24
./pipework net1 solaris 140.252.1.32/24
./pipework net1 gemini 140.252.1.11/24
./pipework net1 gateway 140.252.1.4/24
./pipework net1 netb 140.252.1.183/24

./pipework net2 bsdi 140.252.13.35/27
./pipework net2 sun 140.252.13.33/27
./pipework net2 svr4 140.252.13.34/27

#添加从slip到bsdi的p2p网络
echo "add p2p from slip to bsdi"
#创建一个peer的两个网卡
ip link add name slipside mtu 1500 type veth peer name bsdiside mtu 1500

#把其中一个塞到slip的网络namespace里面
CONTAINER_NS_1=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' slip)
DOCKERPID1=$(basename $CONTAINER_NS_1)
ln -s "$CONTAINER_NS_1" "/var/run/netns/$DOCKERPID1"
ip link set slipside netns ${DOCKERPID1}

#把另一个塞到bsdi的网络的namespace里面
CONTAINER_NS_2=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' bsdi)
DOCKERPID2=$(basename $CONTAINER_NS_2)
ln -s "$CONTAINER_NS_2" "/var/run/netns/$DOCKERPID2"
ip link set bsdiside netns ${DOCKERPID2}

#给slip这面的网卡添加IP地址
docker exec -it slip ip addr add 140.252.13.65/27 dev slipside
docker exec -it slip ip link set slipside up

#给bsdi这面的网卡添加IP地址
docker exec -it bsdi ip addr add 140.252.13.66/27 dev bsdiside
docker exec -it bsdi ip link set bsdiside up

#如果我们仔细分析，p2p网络和下面的二层网络不是同一个网络。

#p2p网络的cidr是140.252.13.64/27，而下面的二层网络的cidr是140.252.13.32/27

#所以对于slip来讲，对外访问的默认网关是13.66
docker exec -it slip ip route add default via 140.252.13.66 dev slipside

#而对于bsdi来讲，对外访问的默认网关13.33
docker exec -it bsdi ip route add default via 140.252.13.33 dev eth1

#对于sun来讲，要想访问p2p网络，需要添加下面的路由表
docker exec -it sun ip route add 140.252.13.64/27 via 140.252.13.35 dev eth1

#对于svr4来讲，对外访问的默认网关是13.33
docker exec -it svr4 ip route add default via 140.252.13.33 dev eth1

#对于svr4来讲，要访问p2p网关，需要添加下面的路由表
docker exec -it svr4 ip route add 140.252.13.64/27 via 140.252.13.35 dev eth1

#这个时候，从slip是可以ping的通net2的所有节点的。

#添加从sun到netb的点对点网络
echo "add p2p from sun to netb"
#创建一个peer的网卡对
ip link add name sunside mtu 1500 type veth peer name netbside mtu 1500

#一面塞到sun的网络namespace里面
CONTAINER_NS_3=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' sun)
DOCKERPID3=$(basename $CONTAINER_NS_3)
ln -s "$CONTAINER_NS_3" "/var/run/netns/$DOCKERPID3"
ip link set sunside netns ${DOCKERPID3}

#另一面塞到netb的网络的namespace里面
CONTAINER_NS_4=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' netb)
DOCKERPID4=$(basename $CONTAINER_NS_4)
ln -s "$CONTAINER_NS_3" "/var/run/netns/$DOCKERPID3"
ip link set netbside netns ${DOCKERPID3}

#给sun里面的网卡添加地址
docker exec -it sun ip addr add 140.252.1.29/24 dev sunside
docker exec -it sun ip link set sunside up

#在sun里面，对外访问的默认路由是1.4
docker exec -it sun ip route add default via 140.252.1.4 dev sunside

#在netb里面，对外访问的默认路由是1.4
docker exec -it netb ip route add default via 140.252.1.4 dev eth1

#在netb里面，p2p这面可以没有IP地址，但是需要配置路由规则，访问到下面net2的二层网络
docker exec -it netb ip link set netbside up
docker exec -it netb ip route add 140.252.1.29/32 dev netbside
docker exec -it netb ip route add 140.252.13.32/27 via 140.252.1.29 dev netbside
docker exec -it netb ip route add 140.252.13.64/27 via 140.252.1.29 dev netbside

#对于netb，配置arp proxy
echo "config arp proxy for netb"

#对于netb来讲，不是一个普通的路由器，因为netb两边是同一个二层网络，所以需要配置arp proxy，将同一个二层网络隔离称为两个。

#配置proxy_arp为1

docker exec -it netb bash -c "echo 1 > /proc/sys/net/ipv4/conf/eth1/proxy_arp"
docker exec -it netb bash -c "echo 1 > /proc/sys/net/ipv4/conf/netbside/proxy_arp"

#通过一个脚本proxy-arp脚本设置arp响应

#设置proxy-arp.conf
#eth1 140.252.1.29
#netbside 140.252.1.92
#netbside 140.252.1.32
#netbside 140.252.1.11
#netbside 140.252.1.4

#将配置文件添加到docker里面
docker cp proxy-arp.conf netb:/etc/proxy-arp.conf
docker cp proxy-arp netb:/root/proxy-arp

#在docker里面执行脚本proxy-arp
docker exec -it netb chmod +x /root/proxy-arp
docker exec -it netb /root/proxy-arp start

#配置上面的二层网络里面所有机器的路由
echo "config all routes"

#在aix里面，默认外网访问路由是1.4
docker exec -it aix ip route add default via 140.252.1.4 dev eth1

#在aix里面，可以通过下面的路由访问下面的二层网络
docker exec -it aix ip route add 140.252.13.32/27 via 140.252.1.29 dev eth1
docker exec -it aix ip route add 140.252.13.64/27 via 140.252.1.29 dev eth1

#同理配置solaris
docker exec -it solaris ip route add default via 140.252.1.4 dev eth1
docker exec -it solaris ip route add 140.252.13.32/27 via 140.252.1.29 dev eth1
docker exec -it solaris ip route add 140.252.13.64/27 via 140.252.1.29 dev eth1

#同理配置gemini
docker exec -it gemini ip route add default via 140.252.1.4 dev eth1
docker exec -it gemini ip route add 140.252.13.32/27 via 140.252.1.29 dev eth1
docker exec -it gemini ip route add 140.252.13.64/27 via 140.252.1.29 dev eth1

#通过配置路由可以连接到下面的二层网络
docker exec -it gateway ip route add 140.252.13.32/27 via 140.252.1.29 dev eth1
docker exec -it gateway ip route add 140.252.13.64/27 via 140.252.1.29 dev eth1

#到此为止，上下的二层网络都能相互访问了

#配置外网访问

echo "add public network"
#创建一个peer的网卡对
ip link add name gatewayin mtu 1500 type veth peer name gatewayout mtu 1500

ip addr add 140.252.104.1/24 dev gatewayout
ip link set gatewayout up

#一面塞到gateway的网络的namespace里面
CONTAINER_NS_5=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' gateway)
DOCKERPID5=$(basename $CONTAINER_NS_5)
ln -s "$CONTAINER_NS_5" "/var/run/netns/$DOCKERPID5"
ip link set gatewayin netns ${DOCKERPID5}

#给gateway里面的网卡添加地址
docker exec -it gateway ip addr add 140.252.104.2/24 dev gatewayin
docker exec -it gateway ip link set gatewayin up

#在gateway里面，对外访问的默认路由是140.252.104.1/24
docker exec -it gateway ip route add default via 140.252.104.1 dev gatewayin

iptables -t nat -A POSTROUTING -o ${publiceth} -j MASQUERADE
ip route add 140.252.13.32/27 via 140.252.104.2 dev gatewayout
ip route add 140.252.13.64/27 via 140.252.104.2 dev gatewayout
ip route add 140.252.1.0/24 via 140.252.104.2 dev gatewayout
