#!/bin/bash

publiceth=$1
imagename=$2

delete_network() {
	network_name="$1"
	if ip link show | grep -q "$network_name"; then
		echo "$network_name"
		ip link delete dev "$network_name"
	fi
}

delete_br() {
	br_name="$1"
	if ovs-vsctl list-br | grep -q "$br_name"; then
		echo "$br_name"
		ovs-vsctl del-br "$br_name"
	fi
}


delete_netns_container() {
	container_name="$1"
	if docker ps -a --format '{{.Names}}' | grep -q "$container_name"; then
		# 容器网络命名空间文件路径
		container_ns=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' $container_name)
		container_ns_id=$(basename $container_ns)

		# 删除软链接文件
		if [ -f "/var/run/netns/$container_ns_id" ]; then
			rm -rf /var/run/netns/$container_ns_id
		fi

		# 删除容器
		if docker ps -a --format '{{.Names}}' | grep -q "$container_name"; then
			docker rm -f "$container_name"
		fi

		# 删除容器网络文件
		if [ -f "$container_ns" ]; then
			rm -f "$container_ns"
		fi
	fi

}

containers=("aix" "solaris" "gemini" "gateway" "netb" "sun" "svr4" "bsdi" "slip")
networks=("slipside" "bsdiside" "netbside" "sunside" "gatewayin" "gatewayout" "aix" "solaris" "gemini" "gateway" "netb" "sun" "svr4" "bsdi" "slip")
bridges=("net1" "net2")

echo "remove cache about containers, network interface and bridges"

for network in "${networks[@]}"; do
	delete_network "veth11$network"
	delete_network "$network"
done

for container_name in "${containers[@]}"; do
	delete_netns_container "$container_name"
done

for bridge in "${bridges[@]}"; do
	delete_br "$bridge"
done
