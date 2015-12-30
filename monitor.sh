#!/bin/bash

function importValues {
  remoteHost=$(cat values/remoteHost)
  mtuSize=$(cat values/mtuSize)
  publicIP=$(cat values/publicIP)
  localHostList=($(cat values/localHostList))
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
      exit 0
    else
      exit 1
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
  currentPublicIP=$(curl -s checkip.dyndns.com | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
  if [[ $1 != $currentPublicIP ]] ; then
    echo "Public IP changed!"
  fi
}

importValues

localSitePoll

publicIPcheck $publicIP