#!/bin/bash
#
configJson="../config.json"
#
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
soga=true; # single-objective GA
moga_wm=false; # multi-objective GA (weight metric method)
moga_ws=false; # multi-objective GA (weight sum method)
#
pExp=2; # p value required for moga (weight metric method)
w_bPS=0.5; # weight bPS required for moga
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
function FIX_SEQUENCE_NAME() {
    sequence="$1"
    sequence=$(echo $sequence | sed 's/.mfasta//g; s/.fasta//g; s/.mfa//g; s/.fa//g; s/.seq//g')
    #
    if [ "${sequence^^}" == "CY" ]; then 
        sequence="CY"
    elif [ "${sequence^^}" == "CASSAVA" ]; then 
        sequence="TME204.HiFi_HiC.haplotig1"
    elif [ "${sequence^^}" == "HUMAN" ]; then
        sequence="chm13v2.0"
    fi
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
        --sequence|--seq|-s)
            sequence="$2";
            FIX_SEQUENCE_NAME "$sequence"
            SEQUENCES+=( "$sequence" );
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
        --p-expoent|--p-exp|--pexp|-pe)
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
    gaFolder="../$ds/$ga";
    evalFolder="$gaFolder/eval"
    generationFolder="$gaFolder/generations"
    mkdir -p $generationFolder
    #
    # add CTIME(m) and CTIME(h) and save into unsorted file
    inputRes="$evalFolder/rawRes.tsv";
    lastPopulation="$generationFolder/g$((gnum-1)).tsv"
    [ $gnum -ne 1 ] && POPULATION_SIZE=$(($(cat $lastPopulation | wc -l)-2)) || POPULATION_SIZE=$(($(cat $inputRes | wc -l)-2))
    unsortedRes="$evalFolder/unsortedRes.tsv"
    awk -F'\t' -v OFS='\t' \
    'NR==1 {print}
    NR==2{
        C_TIME_s=$6
        $6=C_TIME_s"\tC_TIME (m)\tC_TIME (h)"
        print

    }NR>2{
        C_TIME_s=$6
        C_TIME_m=C_TIME_s/60
        C_TIME_h=C_TIME_s/3600
        $6=C_TIME_s"\t"C_TIME_m"\t"C_TIME_h
        print
    }' $inputRes > $unsortedRes
    #
    # get unsorted results of all generations
    allUnsortedFile="$evalFolder/allUnsortedRes.tsv";
    if [ $gnum -eq 1 ]; then
        head -n +2 $unsortedRes | sed -e 's/ - generation.//' > $allUnsortedFile;
    fi
    tail -n +3 $unsortedRes >> $allUnsortedFile;
    #
    # sort all results by their validity, then BYTES_CF, then CTIME (s)
    allSortedRes_bps="$evalFolder/allSortedRes_bps.tsv";
    cat $allUnsortedFile | sort -k2n -k4n -k6n > $allSortedRes_bps;
    #
    # filter all unsorted results by last N generations (num of filtered results cannot be less than $POPULATION_SIZE)
    filteredRes="$evalFolder/filteredRes.tsv";
    for ((oldestGen=$gnum; oldestGen>=1; oldestGen--)); do
        numCmds=$(awk -F'\t' -v oldestGen=$oldestGen 'NR>2 { if ($(NF-1)>=oldestGen) {print $(NF-1)} }' $allUnsortedFile | wc -l);
        if [ $numCmds -ge $POPULATION_SIZE ]; then 
            ( 
                head -n 1 $unsortedRes
                awk 'NR>=2' $allUnsortedFile | sort -k2n -k4n -k6n | head -n $((POPULATION_SIZE+1))
            ) > $filteredRes
            break; 
        fi; 
    done
    #
    if $soga; then
        sortedResFile="$evalFolder/sortedRes.tsv";
        cat $filteredRes | sort -k2n -k4n -k6n > $sortedResFile;
        echo "soga method done";
    #
    else
        #
        # normalize ctime(s), and cmem data (linear scaling)
        # filteredRes ---> normalized
        normalizedResFile="$evalFolder/normalized.tsv";
        size=$(cat $filteredRes | wc -l);
        awk -F'\t' -v OFS='\t' -v size=$size \
        'NR==1 {print}
        NR==2{
            C_TIME_s=$6
            $6=C_TIME_s"\tnC_TIME (s)"

            C_MEM=$9
            $9=C_MEM"\tnC_MEM (GB)"

            print

        }NR>2{
            C_TIME_s=$6
            nC_TIME_s=C_TIME_s/size
            $6=C_TIME_s"\t"nC_TIME_s

            C_MEM=$9
            nC_MEM=C_MEM/size
            $9=C_MEM"\t"nC_MEM

            print
        }' $filteredRes > $normalizedResFile
        #
        # sort by dominance
        # w1: BPS weight; w2: CTIME weight
        sortedResFile="$evalFolder/sortedRes_moga.tsv"
        $moga_wm && moga_wm=1 
        $moga_ws && moga_ws=1 && sortedResFile="$evalFolder/sortedRes_moga_ws.tsv"
        #
        awk -F'\t' -v OFS='\t' -v mogaWm=$moga_wm -v mogaWs=$moga_ws -v w1=$w_bPS -v w2=$w_CTIME -v p=$pExp \
        'NR==1 {print}
        NR==2{
            BYTES=$3
            $3="DOMINANCE\t"BYTES
            print

        }NR>2{
            BYTES=$3
            BPS=$5
            nCTIME_s=$7
            if (mogaWm) {
                DOMINANCE=(w1*BPS^p+w2*nCTIME_s^p)^(1/p)
            } else if (mogaWs) {
                DOMINANCE=w1*BPS+w2*nCTIME_s
            }
            $3=DOMINANCE"\t"BYTES
            print
        }' $normalizedResFile | sort -k2n -k3n -k5n -k7n > $sortedResFile
        #
        (( $moga_wm )) && echo "moga weight metric method done" || echo "moga weight sum method done"      
    fi
    #
    # save evaluated generation
    currentPopFile="$generationFolder/g${gnum}.tsv";
    cat $sortedResFile > $currentPopFile;
    #
    # get adult cmds
    currentAdultCmdsFile="$evalFolder/adultCmds.txt";
    awk -F'\t' 'NR > 2 {print $NF}' $currentPopFile | sed 's/.*C_COMMAND[[:space:]]*//' > $currentAdultCmdsFile;
    #
    # rename file with raw results of current generation
    mv $inputRes "$evalFolder/latestGenRawRes.tsv";
done
