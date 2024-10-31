#!/bin/bash
#
configJson="../config.json"
benchPath="$(grep 'benchPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
mkdir -p $benchPath/results
DS_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
#
dsFolders=( $(find .. -type d -regex "../DS[0-9]+$" -print| sort -V ) )
echo ${dsFolders[@]}
#dsFolders=( "../DS1" )
for dsFolder in ${dsFolders[@]}; do
    evalFiles=( $(find $dsFolder -name "allSortedRes_bps.tsv" -exec echo "{}" \; | sort -V ) )
    dsx=${dsFolder/..\//}
    sequenceName=$(awk '/'$dsx'[[:space:]]/{print $2}' "$DS_sizesBase2")
    dsxBench=$(awk '/'$sequenceName'[[:space:]]/{print $1}' "$benchPath/scripts/$DS_sizesBase2")
    size=$(awk '/'$sequenceName'[[:space:]]/ { print $NF }' "$DS_sizesBase2")
    #
    for evalFile in ${evalFiles[@]}; do
        algoSuffix="$(echo $evalFile | cut -d'/' -f3)"
        [[ ! "$algoSuffix" =~ ^e.*_ga|sampling|randomSearch|localSearch ]] && continue
        algorithm="JV3_$algoSuffix"
        output="$benchPath/results/bench-results-raw-$dsxBench-$sequenceName-$algorithm-$size.txt"
        ( printf "$dsx - $sequenceName - $size \nPROGRAM\tVALIDITY\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tD_TIME (s)\tD_MEM (GB)\tDIFF\tRUN\tC_COMMAND\n" 
        awk -v algo=$algorithm -F'\t' 'NR>2 {
            if ($2==0) print algo"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$9"\t-1\t-1\t0\t"$NF
        }' $evalFile | sort -k2n -k4n -k6n) > $output
        echo $evalFile "---copy-to--->" $output
        [[ "$sequenceName" != "chm13v2.0" ]] && [[ "$algorithm" == *"sampling"* ]] && rm $output && echo "REMOVED OUTPUT: $output"
    done
done
#
