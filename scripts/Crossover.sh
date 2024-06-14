#!/usr/bin/env bash
#
# === FUNCTIONS ================================================================================================
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
  echo "--seed|-sd..........Pseudo-random seed. Default value: $DEFAULT_SEED";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
function CHECK_INPUT () {
  FILE=$1
  if [ -f "$FILE" ]; then
    echo "Input filename exists: $FILE"
  else
    echo -e "\e[31mERROR: input file not found ($FILE)!\e[0m";
    exit;
  fi
}
#
function FIX_SEQUENCE_NAME() {
    sequence="$1"
    echo $sequence
    sequence=$(echo $sequence | sed 's/.mfasta//g; s/.fasta//g; s/.mfa//g; s/.fa//g; s/.seq//g')
    #
    if [ "${sequence^^}" == "CY" ]; then 
        sequence="CY"
    elif [ "${sequence^^}" == "CASSAVA" ]; then 
        sequence="TME204.HiFi_HiC.haplotig1"
    elif [ "${sequence^^}" == "HUMAN" ]; then
        sequence="chm13v2.0"
    fi
    #
    echo "$sequence"
}
#
# === CROSSOVER FUNCTIONS ================================================================================================
#
function MODEL_XPOINT_CROSSOVER() {              
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ X-POINT CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # choose cross points indexes
    maxNumCrosspoints=2;
    numCrosspoints=$((RANDOM % $maxNumCrosspoints + 1));
    crossPointIdxs=( $( seq 0 1 $((NUM_PARAMS_PER_MODEL-1)) | sort -R --random-source=<(yes $((seed=seed+si))) | head -n $numCrosspoints | sort ) ); 
    #
    # xpointCrossoverMask is used to create the actual crossoverMask, where 0 => bit equals previous bit and 1 => bit difers from previous one
    xpointCrossoverMask=(0 0 0 0 0 0 0 0);
    for crossPointIdx in ${crossPointIdxs[@]}; do
        xpointCrossoverMask[$crossPointIdx]=1;
    done
    #
    crossoverMask=();
    for toCutOrNotToCutIdx in ${!xpointCrossoverMask[@]}; do
        if [ $toCutOrNotToCutIdx -eq 0 ]; then
            crossoverMask=( $((RANDOM % 2)) );
        elif [ "${xpointCrossoverMask[$toCutOrNotToCutIdx]}" -eq 0 ]; then # copy previous bit if we are not at a cut point
            crossoverMask+=( ${crossoverMask[-1]} );
        elif [ ${crossoverMask[-1]} -eq 1 ]; then # at a cut point, if previous bit is 1, then current bit is 0
            crossoverMask+=( 0 );
        elif [ ${crossoverMask[-1]} -eq 0 ]; then # at a cut point, if previous bit is 0, then current bit is 1
            crossoverMask+=( 1 );
        else 
            echo "something strange happened when creating x-point crossover mask...";
        fi;
    done;
    echo ${xpointCrossoverMask[@]};
    #
    # to make sure that crossoverMask is not all zeros nor all ones
    crossoverMasksum=$(IFS="+"; echo "scale=3;${crossoverMask[*]}" | bc);
    if [ $crossoverMasksum -eq 0 ] ; then 
        crossoverMask[$((RANDOM % ${#crossoverMask[@]}))]=1;
    elif [ $crossoverMasksum -eq $NUM_PARAMS_PER_MODEL ]; then
        crossoverMask[$((RANDOM % ${#crossoverMask[@]}))]=0;
    fi
    #
    #
    echo "$numCrosspoints point crossover mask (cut indexes: ${crossPointIdxs[@]}) ---> ${crossoverMask[*]}";
    #
    for paramIdx in ${!crossoverMask[@]}; do
        if [ ${crossoverMask[$paramIdx]} -eq 1 ]; then
            # param ("gene") crossover itself
            temp=${cm_params_arr[$paramIdx]};
            cm_params_arr[$paramIdx]=${cm_params_arr2[$paramIdx]};
            cm_params_arr2[$paramIdx]=$temp;
        fi;
    done
}
#
# === DEFAULT VALUES ================================================================================================
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
sequencesPath="../../sequences";
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
#
DEFAULT_SEED=0;
seed=$DEFAULT_SEED;
RANDOM=$seed;
si=10; # seed increment
#
ga="ga";
#
# === PARSING ================================================================================================
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
    --crossover-rate|--xover-rate|--xrate|--cover-rate|--crate|-xr|-cr)
        CROSSOVER_RATE=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    --crossover|--xover|--cover|-x|-c) # xpoint, uniform
        CROSSOVER_OP="$2";
        shift 2;
        ;;
    --gen-num|-g)
        gnum="$2";
        shift 2;
        ;;
    --seed|-sd)
        seed="$2";
        RANDOM=$seed;
        shift 2;
        ;;
    --seed-increment|-si)
        si="$2";
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
if [ ${#SEQUENCES[@]} -eq 0 ]; then
  SEQUENCES=( "${ALL_SEQUENCES[@]}" );
fi
#
for sequenceName in "${SEQUENCES[@]}"; do
    ds=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    #
    selectedCmdsFile="../${ds}/$ga/selectedCmds.txt";
    selectedCmdsFilesArr+=( $( ls $selectedCmdsFile ) );
done
#
for selCmdsFile in ${selectedCmdsFilesArr[@]}; do
    #
    dsModelFolder=$(dirname $selCmdsFile);
    nextGen=$((gnum+1));
    crossoverOutput="$dsModelFolder/crossoverCmds.sh";
    #
    echo "========================================================";
    echo "SELECTION CMDS INPUT: $selCmdsFile";
    echo "CROSSOVER CMDS OUTPUT: $crossoverOutput";
    #
    while read selCmd; do
        selCmds+=( "$selCmd" );
    done < $selCmdsFile;
    #
    crossoverNum=1;
    childCmds=();
    numParentCmds=$(echo "scale=0; (${#selCmds[@]} * $CROSSOVER_RATE)/1" | bc);
    numChildlessCmds=$(echo "scale=0; (${#selCmds[@]} - $numParentCmds)/1" | bc);
    echo "cr: $CROSSOVER_RATE"
    #
    echo "num chosen cmds: ${#selCmds[@]}";
    while [ "${#selCmds[@]}" -gt 0 ]; do
        echo "=========================== CROSSOVER AND MUTATION NUMBER $crossoverNum =====================================";
        #
        cmdsCouple=()
        for i in $(seq 0 1); do
            selCmds[i]="$(echo ${selCmds[i]} | sed 's/\s*-o\s*[^ ]*//')" # remove -o argument (if it exists)
            cmdsCouple+=( "${selCmds[i]}" )
        done
        echo "couple before crossover"
        printf "%s \n" "${cmdsCouple[@]}"
        #
        
    done
done
