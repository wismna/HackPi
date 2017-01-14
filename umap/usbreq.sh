#!/bin/bash
# s means Setup, 
# 80 means device to host (bmRequestType), 
# 06 means get descriptors (bRequest), 
# 03xx means string descriptors (wValue)
#WLENGTHS=`cat /tmp/0.mon.out | grep "s 80 06 03" | cut -d " " -f 10`
WLENGTHS=`dmesg | grep "USB DWC2 REQ 80 06 03" | tee /home/pi/umap/usbreq.log | cut -d "]" -f 2 | cut -d " " -f 9`
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

