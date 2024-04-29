#!/bin/bash

publiceth=$1
imagename=$2

delete_container () {
	container_name="$1"
	if docker ps -a --format '{{.Names}}' | grep -q "$container_name"; then
		docker rm -f "$container_name"
	fi

}

delete_network() {
	network_name="$1"
	if ip link show | grep -q "$network_name"; then
		ip link delete dev "$network_name"
	fi
}

delete_br() {
	br_name="$1"
	if ovs-vsctl list-br | grep -q "$br_name"; then
		ovs-vsctl del-br "$br_name"
	fi
}


#删除容器命名空间软链接
delete_netns() {
	#container network namespace path
	container_ns=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' $1)
	container_ns_id=$(basename $CONTAINER_NS)
	if [ -d "/var/run/netns/$CONTAINER_NS_ID" ]; then
		rm -f /var/run/netns/$CONTAINER_NS_ID
	fi
}

containers=("aix" "solaris" "gemini" "gateway" "netb" "sun" "svr4" "bsdi" "slip")
networks=("slipside" "bsdiside" "netbside" "sunside" "gatewayin" "gatewayout" "aix" "solaris" "gemini" "gateway" "netb" "sun" "svr4" "bsdi" "slip")
bridges=("net1" "net2")

echo "remove cache about containers, network interface and bridges"
for container_name in "${containers[@]}"; do
	delete_container "$container_name"
	#delete_netns $container_name
done

for network in "${networks[@]}"; do
	echo "veth11$network"
	delete_network "veth11$network"
done

for bridge in "${bridges[@]}"; do
	echo "$bridge"
	delete_br "$bridge"
done
