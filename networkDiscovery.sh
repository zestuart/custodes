#!/bin/bash

function displayOutput() {
    local pid=$1
    local textRotate='discovering'
    local dispInt=0.1
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${textRotate#?}
        printf " [%c]  " "$textRotate"
        local textRotate=$temp${textRotate%"$temp"}
        sleep $dispInt
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function hexToDec {
    nh=$(ifconfig | grep broadcast | awk '{print $4'})
    nd=$(($nh % 0x100)) 
    for i in 1 2 3 
    do 
      ((nh = nh / 0x100)) 
      nd="$((nh % 0x100)).$nd" 
    done 
}

function mask2cidr {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
    unset IFS
}

function osConfigure {
    os=$(uname)
    if [[ $os == Darwin ]] ; then
        routeCommand="netstat -nr"
        broadcastLabel=broadcast
    else
        routeCommand=route
        broadcastLabel=bcast
    fi
}

function networkScope() {
    IFS=$'.' 
    read -r i1 i2 i3 i4 <<< "$1"
    read -r m1 m2 m3 m4 <<< "$nd"
    networkAddress=$(printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$(($i2 & m2))" "$((i3 & m3))" "$((i4 & m4))")
    unset IFS
}

function networkDiscovery() {
    if [ ! -d values ] ; then
        mkdir values
    fi
    output=$(nmap -sn $1)
    onlineHosts=$(echo $output | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    echo "$onlineHosts" > values/localHostList
}

function serviceChoice {
    echo -e '\a'
    echo "Discovered hosts are about to be displayed: mark each line you want to discover services on with an x, then press ctrl o followed by ctrl x."
    sleep 3
    cd values/
    if [ ! -d hostPortList ] ; then
        mkdir hostPortList
    fi
    nano localHostList
    numHostsChosen=$(cat localHostList | grep -c x)
    if [ $numHostsChosen == 1 ] ; then
        hostPlural=host
    else
        hostPlural=hosts
    fi
    echo "Done editing: $numHostsChosen $hostPlural will be scanned for services."
    hostsToMonitor=$(cat localHostList | grep x | sed 's/x//')
    if [ -f localHostList ] ; then
        rm localHostList
        touch localHostList
    fi
    for i in ${hostsToMonitor[@]}; do
        nmap $i | grep -E 'tcp|udp' | awk -F '\/' '{print $1}' >> hostPortList/$i
        echo $i >> localHostList
    done
    echo "Discovered services can be found in $(pwd)/hostPortList."
}

osConfigure
defaultGateway=$($routeCommand | grep UG | awk '{print $2}')

if [ ! -f $(pwd)/values/configured ] ; then
    echo "No initial configuration detected, configuring."
    echo $defaultGateway > $(pwd)/values/defaultGateway
    echo 1500 > $(pwd)/values/mtuSize
    echo $(dig +short myip.opendns.com @resolver1.opendns.com) > $(pwd)/values/publicIP
    read -e -p "Please enter a remote IP address or host to test remote connectivity and MTU size against:" remoteIP
    echo $remoteIP > $(pwd)/values/publicIP
    touch $(pwd)/values/configured
else
    echo "Initial configuration detected, skipping config and moving to network discovery."
fi

echo "Determining network parameters, please wait."

if [ -z $1 ] ; then
    hexToDec
    numbits=$(mask2cidr $nd)
    cidr="/$numbits"
    networkScope $defaultGateway
    echo "Network to scan: $networkAddress$cidr"
    networkDiscovery $networkAddress$cidr
else    
    echo "Network to scan: $1"
    networkDiscovery $1
fi

serviceChoice