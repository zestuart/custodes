#!/bin/bash

function environmentTest {
  if [ -f values/configured ] ; then
  requiredFiles=(defaultGateway localHostList mtuSize publicIP remoteHost)
  for i in ${requiredFiles[@]} ; do
    if [[ ! -f values/$i ]] ; then
        echo "missing file: values/$i; aborting"
        exit 1
    fi
  done
  else
    echo "no evidence of initial configuration; aborting"
    exit 1
  fi
}

function importValues {
  remoteHost=$(cat values/remoteHost)
  mtuSize=$(cat values/mtuSize)
  publicIP=$(cat values/publicIP)
  localHostList=($(cat values/localHostList))
  defaultGateway=$(netstat -nr | grep UG | awk '{print $2}')
  routingInterface=$(netstat -nr | grep UG | awk '{print $8}')
}

function mtuCalc() {
  	mode=0
    pass=0
    failPoint=1
    while [[ $failPoint > 0 ]]; do
      mtu=$(ping -D -c 1 -t 1 -s $1 $2 &>/dev/null)
      if [ "$?" -eq "2" ]; then
        if [[ $mode = 0 ]] ; then
          mtuSize=`expr $mtuSize - 10`
        else
          mtuSize=`expr $mtuSize - 1`
        fi
      else
        if [[ $pass = 0 ]] ; then
          mtuSize=`expr $mtuSize + 9`
          mode=1
          pass=1
        else
          echo $mtuSize > /tmp/finalSize
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
  echo $localHostList
  for i in ${localHostList[@]} ; do
    hostPoll $i
    if [ $? -eq 1 ]; then
      echo "$i down!"
      return 1
      else
      echo "$i up!"
      return 0
    fi   
  done
}

function publicIPcheck() {
  currentPublicIP=$(curl -s checkip.dyndns.com | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
  if [ $? -eq 10 ] ; then 
    echo "Unable to determine public IP address; internet connection possibly down."
    return 1
    else
    if [[ $1 != $currentPublicIP ]] ; then
      echo "public IP changed"
      else 
      echo "public IP static"
    fi
  fi
}

environmentTest
importValues

hostPoll $defaultGateway
if [ $? -eq 0 ] ; then
  publicIPcheck $publicIP  
  localSitePoll
else
  echo "Unable to ping default gateway."
fi