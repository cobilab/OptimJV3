#!/bin/bash
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --genetic-algorithm|--algorithm|--ga|-ga|-a)
        ga="$2";
        shift 2; 
        ;;
    --dataset|-ds)
        dsx="DS$(echo "$2" | tr -d "dsDS")";
        size=$(awk '/'$dsx'[[:space:]]/{print $NF}' $ds_sizesBase2);
        shift 2;
        ;;
    --sequence|--seq|-s)
        sequence="$2";
        FIX_SEQUENCE_NAME "$sequence";
        dsx=$(awk '/'$sequence'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
        shift 2;
        ;;
    --percentage-best|--best-percentage|-bp|-pb)
        bestNpercentage="$2";
        shift 2;
        ;;     
    --best|-b)
        bestN="$2";
        shift 2;
        ;;      
    --first-generation|--first-gen|-fg)
        first_gen="$2";
        shift 2;
        ;;
    --last-generation|--last-gen|-lg)
        last_gen="$2";
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
folder="../$dsx/$ga/logs/run/"
#
files=( $(ls $folder | grep ".log"| sort -V) )
generation=1
#
# tmp file columns: splittedfile, compression time (s)
tmpFile="computeTimeSeconds"
cumsumtime=0
#
outputFile="../$dsx/$ga/logs/cumsumtime.txt"
#
( for file in "${files[@]}"; do
    printf "$(echo "$file" | grep -o '[0-9]\+')\t"
    generation=$((generation+1))
    grep -Pzo "TIME.*\nresults stored in:.*\n" $folder/$file | \
    tr -d '\0' | sed -z 's/\nresults stored in: /\t/g' | \
    awk '{print $NF,$2}' | sort > $tmpFile
    [ $(cat $tmpFile | wc -l) -eq 0 ] && printf "$cumsumtime\n" && continue
    #
    splittedFiles=($(awk '{print $1}' $tmpFile | uniq -c | awk '{print $2}'))
    #
    # finds the time it took for the slowest splitted file to finish 
    slowestTime=$(for sf in "${splittedFiles[@]}"; do
        splittedtime=$(cat $tmpFile | grep $sf | awk '{s+=$NF}END{print s}')
        echo $splittedtime
    done | sort -r | head -n1)
    #
    cumsumtime=$(echo "scale=3;$cumsumtime+$slowestTime"|bc) # in seconds
    printf "$cumsumtime\n"
done ) > $outputFile
