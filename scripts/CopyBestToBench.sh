#!/bin/bash
#
configJson="../config.json"
benchPath="$(grep 'benchPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
mkdir -p $benchPath/results
DS_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
#
dsFolders=( $(find .. -type d -name "DS*" -print | sort -V ) )
#dsFolders=( "../DS1" )
for dsFolder in ${dsFolders[@]}; do
    evalFiles=( $(find $dsFolder -name "allSortedRes_bps.tsv" -exec echo "{}" \; | sort -V ) )
    dsname=${dsFolder/..\//}
    sequenceName=$(awk '/'$dsname'[[:space:]]/{print $2}' "$DS_sizesBase2")
    size=$(awk '/'$sequenceName'[[:space:]]/ { print $NF }' "$DS_sizesBase2")
    #
    for evalFile in ${evalFiles[@]}; do
        algorithm="JV3-$(echo $evalFile | cut -d'/' -f3)"
        ( printf "$dsname - $sequenceName - $size \nPROGRAM\tVALIDITY\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tD_TIME (s)\tD_MEM (GB)\tDIFF\tRUN\tC_COMMAND\n" 
        awk -v algo=$algorithm -F'\t' 'NR>2 {
            if ($2==0) print algo"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$9"\t-1\t-1\t0\t"$NF
        }' $evalFile | sort -k2n -k4n -k6n | head -n10 ) > $benchPath/results/bench-results-raw-$dsname-$sequenceName-$algorithm-$size.txt
    done 
    echo
done
