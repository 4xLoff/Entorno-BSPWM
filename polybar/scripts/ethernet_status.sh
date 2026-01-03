#!/bin/sh

#echo "%{F#2495e7} %{F#ffffff}$(/usr/sbin/ifconfig ens33 | grep "inet " | awk '{print $2}')%{u-}"


IP=$(ip route get 1.1.1.1 | awk '{print $7}')
echo "%{F#2495e7} %{F#ffffff}$IP%{u-}"

