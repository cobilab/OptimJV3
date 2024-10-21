#!/bin/bash
#
configJson="../config.json"
toolsPath="$(grep 'toolsPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
rawSequencesPath="$(grep 'rawSequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
#
# first AlcoR example
#
./$toolsPath/AlcoR simulation -rs 2097152:0:1:0:0:0 > $rawSequencesPath/alcor2MB_raw.fa
#
# second AlcoR example, adapted from https://cobilab.github.io/alcor/
#
echo ">repetitive dna" > repetitive_raw.fa;
for((x=1;x<=100;++x));
  do
  echo "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT" >> repetitive_raw.fa;
  done
# 
# This code simulates a sequence containig LCRs in several parts:
#
./$toolsPath/AlcoR simulation -rs 2000:0:1:0:0:0 -fs 1:2000:1:3:0:0:0:repetitive_raw.fa \
-rs 2000:0:11:0:0:0 -fs 1:2000:1:3:0:0:0:repetitive_raw.fa -rs 2000:0:21:0:0:0 \
-rs 2000:0:17:0:0:0 -rs 2000:0:27:0:0:0 -rs 2000:0:17:0:0:0 -rs 2000:0:31:0:0:0 \
-rs 2000:0:47:0:0:0 -rs 2000:0:37:0:0:0 -rs 2000:0:55:0:0:0 -rs 2000:0:67:0:0:0 \
-rs 2000:0:17:0:0:0 -rs 2000:0:71:0:0:0 > $rawSequencesPath/alcor30KB_raw.fa;
#
rm -fr repetitive_raw.fa
