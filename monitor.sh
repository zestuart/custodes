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
    mtuSize=$1
    remoteIP=$2
  	mode=0
    pass=0
    failPoint=1
    while [[ $failPoint > 0 ]]; do
      mtu=$(ping -D -c 1 -t 3 -s $mtuSize $remoteIP &>/dev/null)
      if [ "$?" -eq "1" ]; then
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
          if [[ $mtuSize -ne $(cat values/mtuSize) ]] ; then
            echo "MTU size changed; old: $1, new: $mtuSize"
            echo $mtuSize > values/mtuSize
            else
            echo "MTU size stable."
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
      echo "$i down!"
      else
      echo "$i up!"
    fi   
  done
}

function publicIPcheck() {
  currentPublicIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
  if [ $? -eq 10 ] ; then 
    echo "Unable to determine public IP address; internet connection possibly down."
    return 1
    else
    if [[ $1 != $currentPublicIP ]] ; then
      echo "public IP changed; old: $1, new: $currentPublicIP"
      echo $currentPublicIP > values/publicIP
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
  #localSitePoll
  mtuCalc $mtuSize $remoteHost
else
  echo "Unable to ping default gateway."
fi