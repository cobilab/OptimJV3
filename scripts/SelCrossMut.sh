#!/usr/bin/env bash
#
### FUNCTIONS ###############################################################################################
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
### SELECTION FUNCTIONS ###############################################################################################
#
function ELITIST_SELECTION() {
    echo "=========================== ELITIST SELECTION =====================================";
    chosenCmds=();
    while IFS= read -r line; do
        chosenCmds+=( "${line}" );
    done < <( head -n +$numSelectedCmds $cmdsFileInput );
    echo "elitist selection finished, the following cmds were selected:";
    printf "%s\n" "${chosenCmds[@]}";
}
#
function ROULETTE_SELECTION() {
    echo "=========================== ROULETTE SELECTION =====================================";
    #
    gaFolder="../${ds}/$ga"
    scmFolder="$gaFolder/scm"
    mkdir -p $scmFolder
    # 
    # input file with values required for creating a roulette
    dsFileInput="$gaFolder/g$gnum.tsv"
    echo "ds file input: $dsFileInput; gen num: $gnum"
    #
    roulette="$scmFolder/roulette.tsv"
    initialRoulette="${roulette/roulette/initialRoulette}"
    echo "roulette file: $roulette; initial roulette: $initialRoulette"
    #
    # f size
    fSize=$(awk 'NR>2' $dsFileInput | sed -n '/[^[:space:]]/p' | wc -l)
    echo "|f(x)| = $fSize"
    #
    # sum of all f values, F
    F=$(awk 'NR==2{ if ($10 ~ /DOMINANCE/) {col=10} else {col=4} } NR>2{sum+=$col} END{print sum}' $dsFileInput)
    echo "sum f(x) = F = $F"
    #
    # initialize roulette with f(x), p(x), r(x) and cmd columns
    (   awk -F'\t' -v F=$F -v n=$fSize 'NR==2{ 
        if ($10 ~ /DOMINANCE/) {col=10} else {col=4} # column number
        print "f(x)\tp(x)\tr(x)\tcmds"
    } NR>2{
        f=$col # f(x), bps or domain values
        if (n!=1) { p=(1-f/F)/(n-1) } else { p=1 } # p(x), https://stackoverflow.com/questions/8760473/roulette-wheel-selection-for-function-minimization
        r+=p # r(x), cumulative sum of p(x)
        cmd=$NF
        print f"\t"p"\t"r"\t"cmd
    }' "$dsFileInput" ) > $roulette
    cat $roulette > $initialRoulette
    #
    for i in $(seq 1 $numSelectedCmds); do
        #
        # pick a random number between 0 and 1 to choose a command
        rmin=$(awk 'NR==2{print $3}' $roulette)
        rmax=$(awk 'END{print $3}' $roulette)
        rndNum=0.$((RANDOM%99999))$((RANDOM%9))
        #
        # find selected cmd
        chosenCmd="$(awk -F'\t' -v r=$rndNum 'NR>1{if (r<$3) {print $NF;exit}}' $roulette)"
        chosenCmds+=( "$chosenCmd" )
        chosenRowNum=$(awk -F'\t' -v r=$rndNum 'NR>1{if (r<$3) {print NR;exit}}' $roulette)
        #
        # remove selected cmd from roulette to not choose it again
        ( awk -v nr=$chosenRowNum 'NR!=nr {print}' $roulette ) > $roulette.bak && mv $roulette.bak $roulette
        #
        # update f size
        fSize=$(awk 'NR>1' $roulette | sed -n '/[^[:space:]]/p' | wc -l)
        echo "|f(x)| = $fSize"
        #
        # update sum of all f values, F
        F=$(awk 'NR>1{sum+=$1} END{print sum}' $roulette)
        echo "sum f(x) = F = $F"
        #
        # update roulette stats
        (   awk -F'\t' -v F=$F -v n=$fSize 'NR==1{
            print "f(x)\tp(x)\tr(x)\tcmds"
        } NR>1{
            f=$1 # f(x)
            if (n!=1) { p=(1-f/F)/(n-1) } else { p=1 } # p(x)
            r+=p # r(x)
            cmd=$NF # command
            print f"\t"p"\t"r"\t"cmd
        }' $roulette ) > $roulette.bak && mv $roulette.bak $roulette
    done
}
#
function TOURNAMENT_SELECTION() {
    winner="";
    winnerIdxs=();
    for i in $(seq 1 $numSelectedCmds); do
        cmdIdx1=$((RANDOM%$numSelectedCmds));
        cmdIdx2=$((RANDOM%$numSelectedCmds));
        #
        while : ; do
            cmdIdx1=$((RANDOM%$numSelectedCmds));
            if [ $(printf "%s \n" "${winnerIdxs[@]}" | grep -w $cmdIdx1 -c) -eq 0 ]; then
                break
            fi
        done
        #
        while : ; do
            cmdIdx2=$((RANDOM%$numSelectedCmds));
            if [ $(printf "%s \n" "${winnerIdxs[@]}" | grep -w $cmdIdx2 -c) -eq 0 ]; then
                break
            fi
        done
        #
        if [ $cmdIdx1 -lt $cmdIdx2 ]; then
            winnerIdx=$cmdIdx1;
        else
            winnerIdx=$cmdIdx2;
        fi
        #
        winnerIdxs+=($winnerIdx);
        winner="[idx $winnerIdx] ${cmds[$winnerIdx]}";
        printf "$i  winner between [idx $cmdIdx1] and [idx $cmdIdx2]: $winner\n";
        winner="$(echo $winner | awk -F'] ' '{print $2}')";
        chosenCmds+=( "$winner" );
    done
}
#
### CROSSOVER FUNCTIONS ###############################################################################################
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
###############################################################################################
#
# these lists help to know how to mutate in a valid way
# PARAMETERS COMMON TO CM AND RM
NB_I_lst=(1) # (integer {0,1,2}) manages inverted repeats
#
# CM PARAMETERS - these arrs are used in mutation
# -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
NB_C_cm_lst=( {1..5} ) # CM size. higher values -> more RAM -> better compression
NB_D_lst=( 1 2 5 10 20 50 100 200 500 1000 2000 ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
NB_G_cm_lst=(0.9) # (real [0;1)) gamma; decayment forgetting factor of CM
NB_S_lst=( {0..6} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
NB_E_lst=( 1 2 5 10 20 50 100 ) # ! (integer [1;5000]) denominator that builds alpha on STCM
NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant ga on STCM
NB_A_lst=($(seq 0 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
#
# RM PARAMETERS - these arrs are used in mutation
# -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
NB_C_rm_lst=(12 13) # RM size. higher values -> more RAM -> better compression
NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of repeat models
NB_B_lst=($(seq 0.5 0.1 0.9)) # (real (0;1]) beta. discards or keeps a repeat ga
NB_L_lst=( {4..9} ) # (integer (1;20]) limit threshold; has dependency with NB_B
NB_G_rm_lst=(0.7) # (real [0;1)) gamma; decayment forgetting factor
NB_W_lst=(0.06) # (real (0;1)) initial weight for repeat classes
NB_Y_lst=(2) # (integer {0}, [1;50]) max cache size
#
###############################################################################################
#
# each chromosome has always 8 genes
NUM_PARAMS_PER_MODEL=8;
#
# used in average crossover, intermediate crossover
# a cm "chromosome" has 6 integer "genes" (1) and 2 real "genes" (0)
CM_IS_PARAM_INT=( 1 1 1 0 1 1 1 0 );
#
CROSSOVER_RATE=0.6; # probability of a pair (or set) of cmds in becoming parents
MUTATION_RATE=0.1; # probability of mutation occuring in each cmd
#
SELECTION_OP="elitist";
CROSSOVER_OP="xpoint";
#
numCmds=2; # number of parent cmds per crossover (algorithms for two or more cmds exist)
numSelectedCmds=30; # number of selected commands
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
### PARSING ###############################################################################################
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
        echo $sequence
        #
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
    --num-sel-cmds|-ns)
        numSelectedCmds="$2";
        shift 2;
        ;;
    --crossover-rate|--xover-rate|--xrate|-xr|-cr)
        CROSSOVER_RATE=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    --mutation-rate|--mrate|-mr)
        MUTATION_RATE=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    --selection|--sel|-sl) # elitist, roulette, tournament
        SELECTION_OP="$2";
        shift 2;
        ;;
    --crossover|--xover|-x|-c) # xpoint, uniform
        CROSSOVER_OP="$2";
        shift 2;
        ;;
    --gen-num|-g)
        gnum="$2";
        echo $gnum
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
echo "${SEQUENCES[@]}"
for sequenceName in "${SEQUENCES[@]}"; do
    ds=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    #
    currentAdultCmdsFile="../${ds}/$ga/*adultCmds.txt";
    cmdsFilesInput+=( $( ls $currentAdultCmdsFile) );
    #
    echo "cmds files input: ";
    printf "%s\n" ${cmdsFilesInput[@]}; 
done
# 
for cmdsFileInput in ${cmdsFilesInput[@]}; do
    #
    dsFolder=$(dirname $cmdsFileInput);
    nextGen=$((gnum+1));
    cmdsFileOutput="$dsFolder/g$nextGen.sh";
    #
    populationSize=$(cat $cmdsFileInput | sed '/^\s*$/d' | wc -l); # only counts non-empty lines
    if [ $populationSize -lt $numSelectedCmds ]; then
        numSelectedCmds=$populationSize;
    fi
    #
    echo "========================================================";
    echo "=== ADULT CMDS FILE INPUT: $cmdsFileInput ====";
    echo "=== CHILD CMDS FILE OUTPUT: $cmdsFileOutput ==============";
    echo "========================================================";
    #
    # adult cmds that have already been executed
    cmds=();
    while IFS= read -r line; do
        cmds+=("${line}");
    done < <( cat $cmdsFileInput );     
    #
    ### SELECTION ###############################################################################################
    #
    if [ "$SELECTION_OP" = "elitist" ] || [ "$SELECTION_OP" = "e" ]; then
        ELITIST_SELECTION;
    elif [ "$SELECTION_OP" = "roulette" ] || [ "$SELECTION_OP" = "r" ]; then
        ROULETTE_SELECTION;
    elif [ "$SELECTION_OP" = "tournament" ] || [ "$SELECTION_OP" = "t" ]; then
        TOURNAMENT_SELECTION;
    fi
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
    while [ "${#chosenCmds[@]}" -gt 0 ]; do
        echo "=========================== CROSSOVER AND MUTATION NUMBER $crossoverNum =====================================";
        #
        command="${chosenCmds[0]}";
        command2="${chosenCmds[1]}";
        #
        # original commands
        # command="../bin/JARVIS3 -cm 2:500:1:0.9/4:5:0:0.0 -cm 5:1:1:0.9/2:5:1:0.8  -rm 20:13:0.9:6:0.7:1:0.06:2  -o ../../sequences/TME204.HiFi_HiC.haplotig2.1.seq.jc ../../sequences/TME204.HiFi_HiC.haplotig2.seq"
        # command2="../bin/JARVIS3 -cm 2:100:1:0.9/0:5:1:0.8 -cm 2:5:1:0.9/2:1:0:0.2  -rm 200:13:0.9:4:0.7:1:0.06:2  -o ../../sequences/TME204.HiFi_HiC.haplotig2.2.seq.jc ../../sequences/TME204.HiFi_HiC.haplotig2.seq"
        #
        echo "raw commands randomly chosen for crossover";
        echo ${command[@]}; 
        echo ${command2[@]};
        #
        # DISASSEMBLE "PARENT" COMMANDS ##########################################################################################################################
        #
        # remove -o argument (if it exists)
        command=$(echo "$command" | sed 's/\s*-o\s*[^ ]*//');
        command2=$(echo "$command2" | sed 's/\s*-o\s*[^ ]*//');
        #
        printf "b4 crossing (without -o flag):\n"
        echo $command;
        echo $command2;
        #
        # parse the command string into prefix, cms, rms, suffix
        cms_arr=($(echo "$command" | grep -oE '\-cm [0-9:./]+' | sed 's/-cm//g' | tr '\n' ' '))
        rms_arr=($(echo "$command" | grep -oE '\-rm [0-9:./]+' | sed 's/-rm//g' | tr '\n' ' '))
        #
        command_rev=$(echo "$command" | rev);
        last_cm_rev=$(echo "${cms_arr[-1]}" | rev);
        if [ ${#rms_arr[@]} -gt 0 ]; then last_rm_rev=$(echo "${rms_arr[-1]}" | rev); else last_rm_rev=""; fi;
        #
        substr_before_cm_or_rm=$(echo "$command" | awk '{ match($0, /(-cm|-rm)/); print substr($0, 1, RSTART-1) }');
        substr_after_cm_and_rm=$(echo "$command_rev" | awk -v last_cm_rev=$last_cm_rev -v last_rm_rev=$last_rm_rev '{ 
            if (length(last_rm_rev) == 0) match($0, "(" last_cm_rev ")");
            else match($0, "(" last_cm_rev "|" last_rm_rev ")");
            print substr($0, 1, RSTART-1);
        }' | rev);
        #
        cms_arr2=($(echo "$command2" | grep -oE '\-cm [0-9:./]+' | sed 's/-cm//g' | tr '\n' ' '))
        rms_arr2=($(echo "$command2" | grep -oE '\-rm [0-9:./]+' | sed 's/-rm//g' | tr '\n' ' '))
        #
        echo "cms_arr has ${#cms_arr[@]} CM models"
        echo "cms_arr2 has ${#cms_arr2[@]} CM models"
        #
        command_rev2=$(echo "$command2" | rev);
        last_cm_rev2=$(echo "${cms_arr2[-1]}" | rev);
        if [ ${#rms_arr2[@]} -gt 0 ]; then last_rm_rev2=$(echo "${rms_arr2[-1]}" | rev); else last_rm_rev2=""; fi;
        #
        substr_before_cm_or_rm2=$(echo "$command2" | awk '{ match($0, /(-cm|-rm)/); print substr($0, 1, RSTART-1) }')
        substr_after_cm_and_rm2=$(echo "$command_rev2" | awk -v last_cm_rev2=$last_cm_rev2 -v last_rm_rev2=$last_rm_rev2 '{ 
            if (length(last_rm_rev2) == 0) match($0, "(" last_cm_rev2 ")");
            else match($0, "(" last_cm_rev2 "|" last_rm_rev2 ")");
            print substr($0, 1, RSTART-1);
        }' | rev);
        #
        # CROSSOVER ##########################################################################################################################
        #
        # choose cm indexes where crossover will happen
        chosen_cm_idx=$(( RANDOM % ${#cms_arr[@]} ));
        chosen_cm_idx2=$(( RANDOM % ${#cms_arr2[@]} ));
        #
        echo "chosen cm from cmd1 before crossover (str) ---> " "${cms_arr[chosen_cm_idx]}" " (index " $chosen_cm_idx ")";
        echo "chosen cm from cmd2 before crossover (str) ---> " "${cms_arr2[chosen_cm_idx2]}" " (index " $chosen_cm_idx2 ")";
        #
        # each chosen cm is transformed into an array of 8 parameters ("genes")
        cm_params_arr=($(echo "${cms_arr[chosen_cm_idx]}" | sed 's/[:/]/ /g'));
        cm_params_arr2=($(echo "${cms_arr2[chosen_cm_idx2]}" | sed 's/[:/]/ /g'));
        #
        rndFloat="0.$((RANDOM%999))";
        if (( $(echo "$rndFloat <= $CROSSOVER_RATE" | bc) )); then 
            if [ "$CROSSOVER_OP" = "xpoint" ]; then
                XPOINT_CROSSOVER;
            elif [ "$CROSSOVER_OP" = "uniform" ]; then
                UNIFORM_CROSSOVER;
            elif [ "$CROSSOVER_OP" = "average" ] || [ "$CROSSOVER_OP" = "avg" ]; then
                AVG_CROSSOVER;
            elif [ "$CROSSOVER_OP" = "discrete" ]; then
                DISCRETE_CROSSOVER;
            elif [ "$CROSSOVER_OP" = "flat" ]; then
                FLAT_CROSSOVER;
            elif [ "$CROSSOVER_OP" = "heuristic" ] || [ "$CROSSOVER_OP" = "intermediate" ]; then
                HEURISTIC_CROSSOVER;
            fi
        fi
        #
        # convert param arrs to strs
        cm_params_str=$(printf "%s:" ${cm_params_arr[@]});
        cm_params_str="${cm_params_str%:}";
        cm_params_str=$(echo "$cm_params_str" | sed 's/:/\//4');
        echo "chosen cm from cmd1 after crossover (str) ----> " $cm_params_str
        #
        cm_params_str2=$(printf "%s:" ${cm_params_arr2[@]});
        cm_params_str2="${cm_params_str2%:}";
        cm_params_str2=$(echo "$cm_params_str2" | sed 's/:/\//4');
        echo "chosen cm from cmd2 after crossover (str) ----> " $cm_params_str2
        # 
        # replace cms chosen for crossover with updated cms
        cms_arr[$chosen_cm_idx]=$cm_params_str;
        cms_arr2[$chosen_cm_idx2]=$cm_params_str2;
        #
        echo "cm arr after crossover: ${cms_arr[@]}";
        echo "cm arr 2 after crossover: ${cms_arr2[@]}";
        #
        # MUTATION ##########################################################################################################################
        #
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ MUTATION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
        #
        chosenCmd=$(( RANDOM % $numCmds )); # choose command where mutation will occur
        if [ $chosenCmd -eq 0 ]; then
            chosenCmIdx=$(( RANDOM % ${#cms_arr[@]} ));
            chosenCm="${cms_arr[$chosenCmIdx]}"; # choose CM where mutation will occur (str)
        else 
            chosenCmIdx=$(( RANDOM % ${#cms_arr2[@]} ));
            chosenCm="${cms_arr2[$chosenCmIdx]}"; # choose CM where mutation will occur (str)
        fi;
        echo "chosen cm from command$(($chosenCmd+1)) b4 mutation (str) ----> $chosenCm (index $chosenCmIdx)"
        #
        chosenCmParamsArr=($(echo "$chosenCm" | sed 's/[:/]/ /g')); # CM where mutation will occur (arr)
        #
        # ${cms_arr[@]} ${cms_arr2[@]}
        # create mutation mask
        mutationMask=();
        for (( i=0; i < $NUM_PARAMS_PER_MODEL; i++ )); do     
            if [ $(( RANDOM % 100 )) -gt 1 ]; then
                mutationMask+=( 0 );
            else         
                mutationMask+=( 1 );     
            fi; 
        done;
        echo "mutation mask --------------------------------> ${mutationMask[*]}"
        #
        # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]
        mutationVals=( 
            ${NB_C_cm_lst[$((RANDOM % ${#NB_C_cm_lst[@]}))]}
            ${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}
            ${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]}
            ${NB_G_cm_lst[$((RANDOM % ${#NB_G_cm_lst[@]}))]}
            #
            ${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]}
            ${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]}
            ${NB_R_cm_lst[$((RANDOM % ${#NB_R_cm_lst[@]}))]}
            ${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]}
        );
        #
        for paramIdx in ${!mutationMask[@]}; do
            if [ ${mutationMask[$paramIdx]} -eq 1 ]; then
                chosenCmParamsArr[$paramIdx]=${mutationVals[$paramIdx]}; # mutation itself
            fi;
        done;
        #
        # convert params arr to str
        chosenCmParamsStr="$(printf "%s:" ${chosenCmParamsArr[@]})"; # x:x:x:x:x:x:x:x:
        chosenCmParamsStr="${chosenCmParamsStr%:}"; # x:x:x:x:x:x:x:x
        chosenCmParamsStr="$(echo "$chosenCmParamsStr" | sed 's/:/\//4')"; # x:x:x:x/x:x:x:x
        echo "chosen cm from command$(($chosenCmd+1)) after mutation (str) -> $chosenCmParamsStr"
        #
        # chosen cm arr for mutation ---> updated cm arr with cm that has been mutated in a param
        if [ $chosenCmd -eq 0 ]; then
            cms_arr[$chosenCmIdx]=$chosenCmParamsStr;
        else 
            cms_arr2[$chosenCmIdx]=$chosenCmParamsStr;
        fi;
        #
        echo "cm arr after crossover and possible mutation: ${cms_arr[@]}";
        echo "cm arr2 after crossover and possible mutation: ${cms_arr2[@]}";
        #
        # ASSEMBLE "CHILDREN" COMMANDS ###########################################################################################################################
        #
        # convert cms array and rms array to cms string and rms string, respectively
        cms_str=$(printf "\055cm %s " ${cms_arr[@]});
        if [ ${#rms_arr[@]} -gt 0 ]; then rms_str=$(printf "\055rm %s " ${rms_arr[@]}); else rms_str=""; fi;
        #
        cms_str2=$(printf "\055cm %s " ${cms_arr2[@]});
        if [ ${#rms_arr2[@]} -gt 0 ]; then rms_str2=$(printf "\055rm %s " ${rms_arr2[@]}); else rms_str2=""; fi;
        #
        # commands after crossing
        command=$(echo $substr_before_cm_or_rm $cms_str $rms_str $substr_after_cm_and_rm)
        command2=$(echo $substr_before_cm_or_rm2 $cms_str2 $rms_str2 $substr_after_cm_and_rm2)
        #
        printf "after crossing and possible mutation (without -o arg):\n$command\n$command2\n"   
        #
        # add child cmd only if it's different from any adult cmd and child
        allRawRes="${dsFolder}/*allRawRes.tsv";
        cmd1SameAsParent=$(awk -F'\t' 'NR>2{print $NF}' $allRawRes | grep -c "$command");
        if [ $cmd1SameAsParent -eq 0 ] && [[ ! " ${childCmds[@]} " =~ "$command" ]]; then
            echo "child added to childCmds array: $command";
            childCmds+=("$command");
        else 
            echo "already executed: $command";
        fi
        #
        cmd2SameAsParent=$(awk -F'\t' 'NR>2{print $NF}' $allRawRes | grep -c "$command2");
        if [ $cmd2SameAsParent -eq 0 ] && [[ ! " ${childCmds[@]} " =~ "$command2" ]]; then
            echo "child added to childCmds array: $command2";
            childCmds+=("$command2");
        else 
            echo "already executed: $command2";
        fi
        #
        # pops the 2 first elements of the selected cmds array
        chosenCmds=("${chosenCmds[@]:2}");
        #
        crossoverNum=$(($crossoverNum+1));
    done;
    #
    # write "child" commands into output cmds file
    echo "=========================== CHILDREN CMDS =====================================";
    printf "%s \n" "${childCmds[@]}";
    echo "Number of child cmds: ${#childCmds[@]}";
    ( for child in "${childCmds[@]}"; do
        echo "$child";
    done ) > $cmdsFileOutput;
    #
    # allow execution of script where commands have just been written to
    chmod +x $cmdsFileOutput;
    #
    # if there is no offstring delete script
    if [ ${#childCmds[@]} -eq 0 ]; then
        rm -fr $cmdsFileOutput
        dsX=$(echo "$cmdsFileInput" | awk -F 'DS|/' '{print $3}');
        echo "NO NEW OFFSPRING - POPULATION STAGNATION OF DS${dsX}";
        exit 1;
    fi
done
