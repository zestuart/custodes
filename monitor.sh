#!/bin/bash

function environmentTest {
  if [ -f /home/pi/custodes/values/configured ] ; then
  requiredFiles=(defaultGateway localHostList mtuSize publicIP remoteHost)
  for i in ${requiredFiles[@]} ; do
    if [[ ! -f /home/pi/custodes/values/$i ]] ; then
        logger "Custodes: event=missing_config_file=$i"
        cleanRun=1
        exit 1
    fi
  done
  else
    logger "Custodes: event=no_initial_config"
    echo "No initial config data found."
    cleanRun=1
    exit 1
  fi
}

function importValues {
  remoteHost=$(cat /home/pi/custodes/values/remoteHost)
  mtuSize=$(cat /home/pi/custodes/values/mtuSize)
  publicIP=$(cat /home/pi/custodes/values/publicIP)
  localHostList=($(cat /home/pi/custodes/values/localHostList))
  defaultGateway=$(netstat -nr | grep UG | awk '{print $2}')
  routingInterface=$(netstat -nr | grep UG | awk '{print $8}')
}

function mtuCalc() {
  #add in logic to only run sometimes; time serial divided by something
  mtuSize=$1
  remoteIP=$2
  mode=0
  pass=0
  failPoint=1
  while [[ $failPoint > 0 ]]; do
    mtu=$(ping -D -c 1 -t 2 -s $mtuSize $remoteIP &>/dev/null)
    if [ $? -eq 1 ] ; then
      if [ $mode -eq 0 ] ; then
        mtuSize=`expr $mtuSize - 10`
      else
        mtuSize=`expr $mtuSize - 1`
      fi
    else
      if [ $pass -eq 0 ] ; then
        if [ $mtuSize -ne $1 ] ; then
            mtuSize=`expr $mtuSize + 9`
            mode=1
            pass=1
          else
	    failPoint=0
        fi
      else
      if [[ $mtuSize -ne $(cat /home/pi/custodes/values/mtuSize) ]] ; then
        logger "Custodes: event=mtuSizeChanged  oldMTU=$1 newMTU=$mtuSize"
        cleanRun=1
        echo $mtuSize > /home/pi/custodes/values/mtuSize
      fi
    failPoint=0
    fi
    fi
  done
}

function hostPoll() {
  ping -c 1 -t 5 $1 &> /dev/null
  if [ $? -eq 0 ]; then
      return 0
    else
      return 1
  fi
}

function localSitePoll {
  for i in ${localHostList[@]} ; do
    hostPoll $i
    if [ $? -eq 1 ]; then
      logger "Custodes: event=localHostDown ip=$i"
      cleanRun=1
    fi   
  done
}

function internetCheck() {
  hostPoll $1
  if [ $? -eq 1 ]; then
	logger "Custodes: event=internetDown"
	clearnrun=1
  fi
}

function publicIPcheck() {
  currentPublicIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
  if [ $? -eq 10 ] ; then 
    logger "Custodes: event=unable_to_determine_public_ip"
    clearnrun=1
    return 1
    else
    if [[ $1 != $currentPublicIP ]] ; then
      logger "Custodes: event=publicIPchanged old_public_ip=$1 new_public_ip=$currentPublicIP"
      echo $currentPublicIP > /home/pi/custodes/values/publicIP
    fi
  fi
}

cleanRun=0
environmentTest
importValues

hostPoll $defaultGateway
if [ $? -eq 0 ] ; then
  publicIPcheck $publicIP  
  localSitePoll
  internetCheck $remoteHost
  mtuCalc $mtuSize $remoteHost
else
  echo "Custodes: event=default_gateway_no_icmp"
fi

if [ $cleanRun -eq 0 ] ; then
  logger "Custodes: event=cleanRun"
else
  logger "Custodes: event=failedRun"
fi
