#!/bin/bash
#
configJson="../config.json"
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
# === Start position of 100MB human sequence starts at 40% to avoid telomeres ===
# echo "scale=3;3117292070*0.4 + 1"|bc = 1246916829.0 -> start
# echo "3117292070*0.4 + 100*2^20"|bc = 1351774428.0 -> end
cat $sequencesPath/chm13v2.0.seq | cut -c 1246916829-1351774428 | tr -d '\n' > $sequencesPath/human100MB.seq
#
# === First 50% of 100MB human sequence ===
# 1 -> start
# echo "104857600*0.5"|bc = 52428800.0 -> end
cat $sequencesPath/human100MB.seq | cut -c 1-52428800 | tr -d '\n' > $sequencesPath/human50MB.seq
#
# === First 25% of 100MB human sequence ===
# 1 -> start
# echo "104857600*0.25"|bc = 26214400.0 -> end
cat $sequencesPath/human100MB.seq | cut -c 1-26214400 | tr -d '\n' > $sequencesPath/human25MB.seq
#
# === First 25% of 100MB human sequence ===
# 1 -> start
# echo "104857600*0.125"|bc = 13107200.000 -> end
cat $sequencesPath/human100MB.seq | cut -c 1-13107200 | tr -d '\n' > ../../sequences/human12d5MB.seq
