#!/bin/bash
# Analyze USB Setup Request
# 80 means device to host (bmRequestType)
# 06 means get descriptors (bRequest)
# 03xx means string descriptors (wValue)
# 0409 means english (wIndex)
# wLength is the size of the descriptor and this is what we want
LOGFILE=/home/pi/HackPi/usbreq.log
dmesg | grep "USB DWC2 REQ 80 06 03" | tee $LOGFILE
WLENGTHS=`awk '$9!="0000" { print $10 }' $LOGFILE`
TOTAL=0
COUNTER=0
for i in $WLENGTHS; do
    if [ "$i" = "00ff" ]; then
        let COUNTER=COUNTER+1
    fi
    let TOTAL=TOTAL+1
    #echo wLength: $i
done
#echo $COUNTER
if [ $TOTAL -eq 0 ]; then
    echo Unknown
    exit
fi
#echo $COUNTER
if [ $COUNTER -eq 0 ]; then
    echo MacOs
#elif [ $COUNTER -eq $TOTAL ]; then
#    echo Linux
else
     echo Other
#    echo Windows
fi

