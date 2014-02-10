#!/bin/bash

if test -z $1
then
	echo "starting"
else
	echo "installing"
	rake install
fi
adb logcat -c 
echo "Starting"
rake start 
adb logcat | grep 'Punch\|RUBOTO\|System' 
