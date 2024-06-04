#!/bin/bash
#
# default variables and constants
POPULATION_SIZE=100;
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
soga=true; # single-objective GA
moga_wm=false; # multi-objective GA (weight metric method)
moga_ws=false; # multi-objective GA (weight sum method)
#
pExp=2; # p value required for moga (weight metric method)
w_bPS=0.999999; # weight bPS required for moga
w_CTIME=$(echo "1-$w_bPS" | bc); # weight C_TIME required for moga
#
ga="ga";
#
# === FUNCTIONS ===========================================================================
#
function SHOW_HELP() {
 echo " -------------------------------------------------------";
 echo "                                                        ";
 echo " OptimJV3 - optimize JARVIS3 CM and RM parameters       ";
 echo "                                                        ";
 echo " Program options ---------------------------------------";
 echo "                                                        ";
 echo " --help|-h.....................................Show this";
 echo " --view-datasets|--view-ds|-v....View sequences and size"; 
 echo "                                                 of each";
 echo "--sequence|--seq|-s..........Select sequence by its name";
 echo "--sequence-group|--seq-grp|-sg.Select group of sequences";
 echo "                                           by their size";
 echo "--dataset|-ds......Select sequence by its dataset number";
 echo "--dataset-range|--dsrange|--drange|-dr............Select";
 echo "                   sequences by range of dataset numbers";
 echo "                                                        ";
 echo " -------------------------------------------------------";
}
#
# === PARSING ===========================================================================
#
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --help|-h)
            SHOW_HELP;
            exit;
            shift;
            ;;
        --view-datasets|--view-ds|-v)
            cat $ds_sizesBase2; echo; cat $ds_sizesBase10;
            exit;
            shift;
            ;;
        --genetic-algorithm|--algorithm|--ga|-ga|-a)
            ga="$2";
            shift 2; 
            ;;
        --sequence-group|--sequence-grp|--seq-group|--seq-grp|-sg)
            size="$2";
            SEQUENCES+=( $(awk '/[[:space:]]'$size'/ { print $2 }' "$ds_sizesBase2") );
            shift 2; 
            ;;
            --dataset|-ds)
            dsnum=$(echo "$2" | tr -d "dsDS");
            SEQUENCES+=( "$(awk '/DS'$dsnum'[[:space:]]/{print $2}' "$ds_sizesBase2")" );
            shift 2;
            ;;
        --dataset-range|--dsrange|--drange|-dr)
            input=( $(echo "$2" | sed 's/[:/]/ /g') );
            sortedInput=( $(printf "%s\n" ${input[@]} | sort -n ) );
            dsmin="${sortedInput[0]}";
            dsmax="${sortedInput[1]}";
            SEQUENCES+=( $(awk -v m=$dsmin -v M=$dsmax 'NR>=1+m && NR <=1+M {print $2}' "$ds_sizesBase2") );
            shift 2;
            ;;
        --gen-num|--gen|-g)
            gnum="$2";
            shift 2;
            ;;
        --population-size|--population|--psize|-ps)
            POPULATION_SIZE="$2";
            shift 2;
            ;;
        --moga-weightned-metric|--moga-wm|--moga)
            soga=false;
            moga_wm=true;
            shift;
            ;;
        --moga-weightned-sum|--moga-ws)
            soga=false;
            moga_ws=true;
            shift;
            ;;
        --p-expoent|--p-exp|-pe)
            pExp="$2";
            shift 2;
            ;;
        --weight-bps|--w-bps|-wBPS|-w1)
            w_bPS="$2";
            w_CTIME=$(echo "1-$w_bPS" | bc);
            shift 2;
            ;;
        --weight-ctime|--w-ctime|-wCTIME|-w2)
            w_CTIME="$2";
            w_bPS=$(echo "1-$w_CTIME" | bc);
            shift 2;
            ;;
        *) 
            echo "Invalid option: $1"
            exit 1;
            ;;
    esac
done
#
# === MAIN ===========================================================================
#
datasets=();
for sequenceName in ${SEQUENCES[@]}; do
   datasets+=( $(awk '/[[:space:]]'$sequenceName'[[:space:]]/ {print $1}' $ds_sizesBase2 ) );
done
#
for ds in ${datasets[@]}; do
    dsFolder="../${ds}/$ga";
    #
    # get raw results of all generations
    currentRawResFile="$dsFolder/g${gnum}_raw.tsv";
    allRawResFile="$dsFolder/allRawRes.tsv";
    if [ $gnum -eq 1 ]; then
        head -n +2 $currentRawResFile | sed -e 's/ - generation.//' > $allRawResFile;
    fi
    tail -n +3 $currentRawResFile >> $allRawResFile;
    #
    # sort all results by BPS, then CTIME (s)
    allSortedRes_bps="$dsFolder/allSortedRes_bps_ctime_s.tsv";
    cat $allRawResFile | sort -k4n -k5n > $allSortedRes_bps;
    #
    # sort all results by BPS, then CTIME (converted to minutes)
    allSortedRes_bps_ctime_m="$dsFolder/allSortedRes_bps_ctime_m.tsv";
    awk -v OFS="\t" -F'\t' '{if (NR==2) {$5="C_TIME (m)"} else if (NR>2) {$5=$5/60} print}' $allSortedRes_bps > $allSortedRes_bps_ctime_m;
    #
    # sort all results by BPS, then CTIME (converted to hours)
    allSortedRes_bps_ctime_h="$dsFolder/allSortedRes_bps_ctime_h.tsv";
    awk -v OFS="\t" -F'\t' '{if (NR==2) {$5="C_TIME (h)"} else if (NR>2) {$5=$5/3600} print}' $allSortedRes_bps > $allSortedRes_bps_ctime_h;
    #
    # filter raw results by last N generations (num of filtered results cannot be less than $POPULATION_SIZE)
    rawFilterResFile="$dsFolder/aRawFilterRes.tsv";
    for ((oldestGen=$gnum; oldestGen>=0; oldestGen--)); do
        numCmds=$(awk -F'\t' -v oldestGen=$oldestGen 'NR>2 { if ($(NF-1)>=oldestGen) {print $(NF-1)} }' $allRawResFile | wc -l);
        if [ $numCmds -ge $POPULATION_SIZE ]; then 
            ( head -n +2 $currentRawResFile;
            awk -F'\t' -v oldestGen=$oldestGen 'NR>2 { if ($(NF-1)>=oldestGen) {print} }' $allRawResFile;
            )> $rawFilterResFile;
            break; 
        fi; 
    done
    #
    # normalize bps, ctime, and cmem data (linear scaling)
    normalizedResFile="$dsFolder/aNormalized.tsv";
    normalizedTMP="$dsFolder/aNormalizedTMP.tsv";
    size=$(cat $rawFilterResFile | wc -l);
    #
    awk -F'\t' -v OFS='\t' -v m=$ctime_min -v M=$ctime_max 'NR > 2 { $4="|"$4"|"; $5=$5"|"; $6=$6"|"; $NF="\x22"$NF"\x22"; print }' $rawFilterResFile > $normalizedTMP;
    ( head -n +1 $rawFilterResFile;
    printf "PROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tBPSn\tC_TIMEn (s)\tC_MEMn (GB)\tD_TIME (s)\tD_MEM (GB)\tDIFF\tGEN_BIRTH\tC_COMMAND\n";
    awk -F'|' -v OFS='\t' -v size=$size \
    '{ print $1"\t"$2"\t"$3"\t"$4"\t"$2"\t"$3/size"\t"$4/size"\t"$5 }' \
    $normalizedTMP | tr -s '\t' '\t' | tr -d '"' | sort -k4n -k5n )> $normalizedResFile;
    rm -fr $normalizedTMP;
    #
    # sort results by either soga or moga strategies
    # if [ $wCTIME -gt 0.5 ]; then
    #     sortFlags=" -k5n -k4n"; # sort by CTIME before BPS
    # else
    #     sortFlags=" -k4n -k5n"; # sort by BPS before CTIME
    # fi
    #
    if $soga; then
        sortedResFile="$dsFolder/aSortedRes_bps.tsv";
        cat $normalizedResFile > $sortedResFile;
    elif $moga_wm; then
        sortedResFile="$dsFolder/aSortedRes_moga.tsv";
        mogaTMP="$dsFolder/aSortedRes_mogaTMP.tsv";
        awk -F'\t' -v OFS='\t' 'NR > 2 { $7="|"$7"|"; $8=$8"|"; $9=$9"|"; $NF="\x22"$NF"\x22"; print }' $normalizedResFile > $mogaTMP;
        ( head -n +1 $rawFilterResFile;
        printf "PROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tBPSn\tC_TIMEn (s)\tC_MEMn (GB)\tDOMINANCE\tD_TIME (s)\tD_MEM (GB)\tDIFF\tGEN_BIRTH\tC_COMMAND\n";
        awk -v OFS='\t' -v p=$pExp -v w1=$w_bPS -v w2=$w_CTIME -F'|' '{ print $1"\t"$2"\t"$3"\t"$4"\t"(w1*$2^p+w2*$3^p)^(1/p)"\t"$5 }' $mogaTMP | tr -s '\t' '\t' | tr -d '"' | sort -k10n )> $sortedResFile;
        rm -fr $mogaTMP;
        echo "moga weight metric method done";
    elif $moga_ws; then
        sortedResFile="$dsFolder/aSortedRes_moga_ws.tsv";
        mogaTMP="$dsFolder/aRawFilterRes_moga_ws_tmp.tsv";
        awk -F'\t' -v OFS='\t' 'NR > 2 { $7="|"$7"|"; $8=$8"|"; $9=$9"|"; $NF="\x22"$NF"\x22"; print }' $normalizedResFile > $mogaTMP;
        ( head -n +1 $rawFilterResFile;
        printf "PROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tBPSn\tC_TIMEn (s)\tC_MEMn (GB)\tDOMINANCE\tD_TIME (s)\tD_MEM (GB)\tDIFF\tGEN_BIRTH\tC_COMMAND\n";
        awk -v OFS='\t' -v p=$pExp -v w1=$w_bPS -v w2=$w_CTIME -F'|' '{ print $1"\t"$2"\t"$3"\t"$4"\t"w1*$2+w2*$3"\t"$5 }' $mogaTMP | tr -s '\t' '\t' | tr -d '"' | sort -k10n )> $sortedResFile;
        rm -fr $mogaTMP;
        echo "moga weight sum method done";
    fi
    #
    # update population
    currentPopFile="$dsFolder/g${gnum}.tsv";
    awk -v population=$POPULATION_SIZE 'NR<=2+population {print}' $sortedResFile > $currentPopFile;
    #
    # get adult cmds
    currentAdultCmdsFile="$dsFolder/adultCmds.txt";
    awk -F'\t' 'NR > 2 {print $NF}' $currentPopFile | sed 's/.*C_COMMAND[[:space:]]*//' > $currentAdultCmdsFile;
    #
    # remove file with raw results of current generation
    rm -fr $currentRawResFile;
done
