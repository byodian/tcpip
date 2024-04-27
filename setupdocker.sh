#!/bin/bash
IFNAME=$1
CONTAINER_NAME=$2
IPADDR=$3
MACADDR=$4

# Google Styleguide says error messages should go to standard error.
warn () {
  echo "$@" >&2
}

die () {
  status="$1"
  shift
  warn "$@"
  exit "$status"
}

installed() {
	command -v "$1" >/dev/null 2>&1
}

# First step: determine type of first argument (bridge, physical interface...)
if [ -d "/sys/class/net/$IFNAME" ]
then
	if [ -d "/sys/class/net/$IFNAME/bridge" ]; then
		IFTYPE=bridge
		BYTYPE=linux
	elif installed ovs-vsctl && ovs-vsctl list-br|grep -q "^${IFNAME}&"; then
		IFTYPE=bridge
		BYTYPE=openvswitch
	elif [ "$(cat "/sys/class/net/$IFNAME/type")" -eq 32 ]; then # Infiniband IPoIB interface type 32
	      IFTYPE=ipoib
	      # The IPoIB kernel module is fussy, set device name to ib0 if not overridden
	      CONTAINER_IFNAME=${CONTAINER_IFNAME:-ib0}
	else IFTYPE=phys
	fi
else
	case "$IFTYPE" in
		br*)
			IFTYPE=bridge
			BRTYPE=linux
			;;
		ovs*)
			if ! installed ovs-vsctl; then
				die 1 "Need OVS installed on the system to create an ovs bridge"
			fi
			IFTYPE=bridge
			BYTYPE=openvswitch
			;;
		*) die 1 "I do not know how to setup interface $IFNAME.";;
	esac
fi

CONTAINER_IFNAME=${CONTAINER_IFNAME:-eth0}

[ ! -d /var/run/netns ] && mkdir -p /var/run/netns
CONTAINER_NS=$(docker inspect --format='{{ .NetworkSettings.SandboxKey }}' $CONTAINER_NAME)
CONTAINER_NS_ID=$(basename $CONTAINER_NS)

rm -f "/var/run/netns/$CONTAINER_NS_ID"
ln -s "$CONTAINER_NS" "/var/run/netns/$CONTAINER_NS_ID"

MTU=$(ip link show "$IFNAME" | awk '{print $5}')

# If it's a bridge, we need to create a veth pair
[ "IFTYPE" = bridge ] && {
	LOCAL_IFNAME="v${CONTAINER_IFNAME}pl${CONTAINER_NS_ID}"
	GUEST_IFNAME="v${CONTAINER_IFNAME}pg${CONTAINER_NS_ID}"
	ip link add name "$LOCAL_IFNAME" mtu "$MTU" type veth peer name "$GUEST_IFNAME" mtu "$MTU"

	case "$BYTYPE" in
		linux)
			(ip link set "$LOCAL_IFNAME" master "IFNAME" >/dev/null 2>&1) || (brctl addif "$IFNAME" "$LOCAL_IFNAME")
			;;
		openvswitch)
			ovs-vsctl add-port "$IFNAME" "$LOCAL_IFNAME" ${VLAN:+tag="$VLAN"}
			;;
	esac
	ip link set "$LOCAL_IFNAME" up
}

# add another peer network interface to container network namespace
ip link set "$GUEST_IFNAME" netns "$CONTAINER_NS_ID"
ip netns exec "$CONTAINER_NS_ID" ip link set "$GUEST_IFNAME" name "$CONTAINER_IFNAME"
[ "$MACADDR" ] && ip netns exec "$CONTAINER_NS_ID" ip link set dev "$CONTAINER_IFNAME" address "$MACADDR"

# setting container network interface ip
ip netns exec "$CONTAINER_NS_ID" ip addr add "$IPADDR" dev "$CONTAINER_IFNAME"

# Give our ARP neighbors a nudge about the new interface
if installed arping; then
  IPADDR=$(echo "$IPADDR" | cut -d/ -f1)
  ip netns exec "$CONTAINER_NS_ID" arping -c 1 -A -I "$CONTAINER_IFNAME" "$IPADDR" > /dev/null 2>&1 || true
else
  echo "Warning: arping not found; interface may not be immediately reachable"
fi

# Remove NSPID to avoid `ip netns` catch it.
rm -f "/var/run/netns/$CONTAINER_NS_ID"
