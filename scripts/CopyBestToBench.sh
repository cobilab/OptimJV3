#!/bin/bash
#
configJson="../config.json"
benchPath="$(grep 'benchPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
#
dsFolders=( $(find .. -type d -name "DS*" -print | sort -V ) )
dsFolders=( "../DS1" )
for dsFolder in ${dsFolders[@]}; do
    evalFiles=( $(find $dsFolder -name "allSortedRes_bps.tsv" -exec echo "{}" \; | sort -V ) )
    for evalFile in ${evalFiles[@]}; do
        awk -F'\t' 'NR>2 {print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$9"\t-1\t-1\t0\t"$NF}' $evalFile
    done | sort -k2n -k4n -k6n | head -n1 >> $benchPath/results/*${dsFolder/..\/}-*.txt
done
