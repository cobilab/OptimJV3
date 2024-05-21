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
# === CROSSOVER FUNCTIONS ================================================================================================
#
function XPOINT_CROSSOVER() {              
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
function UNIFORM_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ UNIFORM CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    #
    # create mask
    for (( i=0; i < $NUM_PARAMS_PER_MODEL; i++)); 
        do crossoverMask+=( $(( RANDOM % 2 )) ); 
    done;
    #
    # to make sure that the mask has at least one elem equal to 1
    crossoverMasksum=$(IFS="+"; echo "scale=3;${crossoverMask[*]}" | bc);
    if [ $crossoverMasksum -eq 0 ]; then 
        crossoverMask[$((RANDOM % ${#crossoverMask[@]}))]=1;
    fi
    #
    echo "crossover mask -------------------------------> ${crossoverMask[*]}";
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
function AVG_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ AVG CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    for paramIdx in ${!CM_IS_PARAM_INT[@]}; do
        cmParam1=${cm_params_arr[$paramIdx]} # parent 1
        cmParam2=${cm_params_arr2[$paramIdx]} # parent 2
        #
        # the avg of two params within integer domains must be integer
        if [ ${CM_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then 
            avgParam=$(echo "scale=0;($cmParam1+$cmParam2)/2" | bc);
        else # avg of two real nums
            avgParam=$(echo "scale=3;($cmParam1+$cmParam2)/2" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        fi
        #
        cm_params_arr[$paramIdx]=$avgParam;
        #
        # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
        cm_params_arr2[$paramIdx]=$avgParam; 
    done
}
#
function DISCRETE_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DISCRETE CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # r=random.choice({x, y}), if r==0, childParam=p1Param; elif r==1, childParam=p2Param
    for paramIdx in $(seq 0 1 $((NUM_PARAMS_PER_MODEL-1)) ); do
        cmParam1="${cm_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${cm_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        # 
        cmParamChoices=( "$cmParam1" "$cmParam2" ); # chose param with idx=$paramIdx from either parent1 or parent2
        rndIdx=$((RANDOM % 2)); # random value taken from U(0,1)
        chosenCmParam=${cmParamChoices[$rndIdx]};
        #
        # one child may become duplicate of another, but if that is the case, then it is removed later in the script
        cm_params_arr[$paramIdx]=$chosenCmParam;
        cm_params_arr2[$paramIdx]=${cm_params_arr[$paramIdx]};
    done;
}
#
function FLAT_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ FLAT CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    for paramIdx in ${!CM_IS_PARAM_INT[@]}; do
        cmParam1="${cm_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${cm_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        #
        # child param is same as its parents if both parents' params are equal
        childParam=$cmParam1;
        #
        # choose a rnd number from U(lowerCmParam, greaterCmParam) if parents' params are diff
        if [ $(echo "$cmParam1 != $cmParam2" | bc -l) -eq 1 ]; then
            cmParam1and2=( $cmParam1 $cmParam2 );
            IFS=$'\n'; cmParam1and2sorted=($(sort -n <<<"${cmParam1and2[*]}")); unset IFS;
            #
            cmParamMin=${cmParam1and2sorted[0]};
            cmParamMax=${cmParam1and2sorted[-1]};
            #
            # random real number choosen from U(cmParamMin, cmParamMax)
            childParam=$( seq $cmParamMin 0.1 $cmParamMax | sort -R --random-source=<(yes $((seed=seed+si))) | head -n 1 );
    
            #
            # round number to int if param type is int
            if [ ${CM_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then
                childParam=$(echo "scale=0; $childParam/1" | bc);
            fi
        fi
        #
        # one child may become duplicate of another, but if that is the case, then it is removed later in the script
        cm_params_arr[paramIdx]=$childParam;
        cm_params_arr2[paramIdx]=${cm_params_arr[paramIdx]};
    done
}
#
function HEURISTIC_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ HEURISTIC CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # formula to produces ONE child (per param) = p1 + random * ratio_weight * (p2 - p1)
    for paramIdx in ${!CM_IS_PARAM_INT[@]}; do
        cmParam1="${cm_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${cm_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        #
        randomNum="0.$((RANDOM%999))";
        ratioWeight=1;
        #
        childParam=$(echo "scale=3; $cmParam1 + $randomNum * $ratioWeight * ($cmParam2 - $cmParam1)" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        #
        if [ ${CM_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then # round value to int if params are int
            childParam=$(echo "scale=0; $childParam/1" | bc);
        fi
        #
        cm_params_arr[$paramIdx]=$childParam;
        #
        # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
        cm_params_arr2[$paramIdx]=$childParam;
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
SELECTION_OP="elitist";
numSelectedCmds=30; # number of selected commands
#
model="model";
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
    --model-folder|--model|-m)
        model="$2";
        shift 2; 
        ;;
    --sequence|--seq|-s)
        sequence="$2";
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
    --crossover-rate|--xover-rate|--xrate|-xr|-cr)
        CROSSOVER_RATE=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    --crossover|--xover|-x) # xpoint, uniform
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
        # ignore any other arguments
        shift;
    ;;
    esac
done
#
if [ ${#SEQUENCES[@]} -eq 0 ]; then
  SEQUENCES=( "${ALL_SEQUENCES[@]}" );
fi
#
echo "${SEQUENCES[@]}"
for sequenceName in "${SEQUENCES[@]}"; do
    ds=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    #
    currentAdultCmdsFile="../${ds}/$model/*selAdultCmds.txt";
    cmdsFilesInput+=( $( ls $currentAdultCmdsFile ) );
    #
    echo "cmds files input: ";
    printf "%s\n" ${cmdsFilesInput[@]}; 
done
#
for cmdsFileInput in ${cmdsFilesInput[@]}; do
    #
    dsModelFolder=$(dirname $cmdsFileInput);
    nextGen=$((gnum+1));
    cmdsFileOutput="$dsModelFolder/crossoverCmds.sh";
    #
    echo "========================================================";
    echo "=== ADULT CMDS FILE INPUT: $cmdsFileInput ====";
    echo "=== CHILD CMDS FILE OUTPUT: $cmdsFileOutput ==============";
    echo "========================================================";
    #
    while read line; do
        chosenCmds+=( "$line" );
    done < $cmdsFileInput;
    #
    crossoverNum=1;
    childCmds=();
    numParentCmds=$(echo "scale=0; (${#chosenCmds[@]} * $CROSSOVER_RATE)/1" | bc);
    numChildlessCmds=$(echo "scale=0; (${#chosenCmds[@]} - $numParentCmds)/1" | bc);
    echo "cr: $CROSSOVER_RATE"
    echo "num  of parent cmds: $numParentCmds"
    echo "num of childless cmds: $numChildlessCmds";
    #
    echo "num chosen cmds: ${#chosenCmds[@]}";
    # while [ "${#chosenCmds[@]}" -gt 0 ]; do
    #     echo "=========================== CROSSOVER AND MUTATION NUMBER $crossoverNum =====================================";
    #     #
    #     command="${chosenCmds[0]}";
    #     command2="${chosenCmds[1]}";
    #     #
    # done
done