#!/bin/bash
#
# default variables and constants
POPULATION=100;
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
function getSizeSlidingWindow() {
    oldestGenToLive=$gnum;
    while [ $oldestGenToLive -ne 0 ]; do
        numIndividuals=$(awk -v oldestGenToLive=$oldestGenToLive '{if ($10 >= oldestGenToLive) count++} END {print count}' "$tsvBody");
        if [ $numIndividuals -ge $POPULATION ]; then
            break;
        fi;
        oldestGenToLive=$((oldestGenToLive-1));
    done
}
#
function updateResHeader() {
    tsvHeaderNR1="${tsvHeader//_header.tsv/_headerNR1.tsv}";
    tsvHeaderNR2="${tsvHeader//_header.tsv/_headerNR2.tsv}";
    awk NR==1 $rawFile > $tsvHeaderNR1;
    awk 'FNR == 2 {$4="|"$4; print}' $rawFile | awk -F'|' '{print $1"DOMINANCE\t"$2}' > $tsvHeaderNR2;
    cat $tsvHeaderNR1 $tsvHeaderNR2 > $tsvHeader;
    rm -fr $tsvHeaderNR1 $tsvHeaderNR2;
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
        --population|--pop|-p)
            POPULATION="$2";
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
        --p-expoent|--p-exp)
            pExp="$2";
            shift 2;
            ;;
        --weight-bps|--w-bps|-w1)
            w_bPS="$2";
            w_CTIME=$(echo "1-$w_bPS" | bc);
            shift 2;
            ;;
        --weight-ctime|--w-ctime|-w2)
            w_CTIME="$2";
            w_bPS=$(echo "1-$w_CTIME" | bc);
            shift 2;
            ;;
        *) 
            # ignore any other arguments
            shift
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
rawFiles=()
for ds in ${datasets[@]}; do
    rawFiles+=( "../${ds}/g${gnum}_raw.tsv" );
done
#
for rawFile in ${rawFiles[@]}; do
    #
    tsvBody="${rawFile//_raw.tsv/_body.tsv}";
    tsvHeader="${tsvBody//_body.tsv/_header.tsv}";
    tsvFile="${tsvBody//_body.tsv/.tsv}";
    tsvBodyTMP="${tsvBody//.tsv/TMP.tsv}";
    echo $tsvBody $tsvFile $tsvBodyTMP;
    #
    # unordered results (without header) are saved in $tsvBody
    tail -n +3 $rawFile > $tsvBody;
    #
    # aggregate results from previous generation
    if [ $gnum -ne 0 ]; then
        prevTsvBody="${tsvBody/g${gnum}_body/g$(($gnum-1))_body}";
        cat $prevTsvBody >> $tsvBody;
    fi
    #
    # sort results based on fitness function (single-objective GA) or dominance (multi-objective GA)
    if $soga; then
        sort -k4n,4 -k5n,5 -o $tsvBody $tsvBody;
        echo "results from $tsvBody have been sorted by bPS (fitness function), followed by C_TIME";
        head -n +2 $rawFile > $tsvHeader;
    elif $moga_wm; then
        awk -F'\t' -v OFS='\t' '{ $4="|"$4"|"; $5=$5"|"; $NF="\x22"$NF"\x22"; print }' $tsvBody > $tsvBodyTMP;
        awk -v OFS='\t' -v p=$pExp -v w1=$w_bPS -v w2=$w_CTIME -F'|' '{ print $1"\t"(w1*$2^p+w2*$3^p)^(1/p)"\t"$2"\t"$3"\t"$4 }' $tsvBodyTMP | tr -s '\t' '\t' | tr -d '"' > $tsvBody;
        rm -fr $tsvBodyTMP;
        sort -k4n,4 -o $tsvBody $tsvBody;
        echo "results from $tsvBody have been sorted by weighted metric of bPS and C_TIME (dominance function of MOGA)";
        updateResHeader;
    elif $moga_ws; then
        awk -F'\t' -v OFS='\t' '{ $4="|"$4"|"; $5=$5"|"; $NF="\x22"$NF"\x22"; print }' $tsvBody > $tsvBodyTMP;
        awk -v OFS='\t' -v w1=$w_bPS -v w2=$w_CTIME -F'|' '{ print $1"\t"w1*$2+w2*$3"\t"$2"\t"$3"\t"$4 }' $tsvBodyTMP | tr -s '\t' '\t' | tr -d '"' > $tsvBody;
        # rm -fr $tsvBodyTMP;
        sort -k4n,4 -o $tsvBody $tsvBody;
        echo "results from $tsvBody have been sorted by weighted sum of bPS and C_TIME (dominance function of MOGA)";
        updateResHeader;
    else
        echo -e "\e[31mERROR at Evaluation.sh: one of these options should have been chosen: soga (default); --moga-ws; or --moga-wm \e[0m"; 1>&2
    fi
    #
    # add header to processed results, then remove header file
    cat $tsvHeader > $tsvFile;
    rm -fr $tsvHeader;
    #
    # add body to processed results
    # getSizeSlidingWindow;
    head -n $POPULATION $tsvBody >> $tsvFile;
    #
    # write sorted adult cmds into text file (it is not a script, since they are not supposed to be executed again)
    adultCmds="${tsvBody//_body.tsv/_adultCmds.txt}";
    cat $tsvFile | awk -F'\t' 'NR > 2 {print $NF}' | sed 's/.*C_COMMAND[[:space:]]*//' > $adultCmds;
done