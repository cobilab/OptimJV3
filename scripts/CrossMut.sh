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
}
#
function SAVE_SEED() {
    seedAndSiFile="$gaFolder/seed_and_si.txt"
    printf "$seed\t$si\n" > $seedAndSiFile
}
#
function GET_SEED() {
    seedAndSiFile="$gaFolder/seed_and_si.txt"
    if [ -f $seedAndSiFile ]; then
        [ -z "$seed" ] && seed=$(awk '{print $1}' $seedAndSiFile) && RANDOM=$seed
        [ -z "$si" ] && si=$(awk '{print $2}' $seedAndSiFile)
    else 
        [ -z "$seed" ] && seed=1 && RANDOM=$seed
        [ -z "$si" ] && si=10
        printf "$seed\t$si\n" > $seedAndSiFile
    fi
}
#
function DISASSEMBLE_PARENT_CMDS() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DISSASSEMBLE "PARENT" COMMANDS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    #
    # remove -o argument (if it exists)
    cmd=$(echo "$cmd" | sed 's/\s*-o\s*[^ ]*//');
    cmd2=$(echo "$cmd2" | sed 's/\s*-o\s*[^ ]*//');
    #
    printf "b4 crossing (without -o flag):\n"
    echo $cmd;
    echo $cmd2;
    #
    # parse the cmd string into prefix, cms, rms, suffix
    cmd1cmsArr=($(echo "$cmd" | grep -oE '\-cm [0-9:./]+' | sed 's/-cm//g' | sort -R --random-source=<(yes $seed) | tr '\n' ' ')); seed=$((seed+si))
    cmd1rmsArr=($(echo "$cmd" | grep -oE '\-rm [0-9:./]+' | sed 's/-rm//g' | sort -R --random-source=<(yes $seed) | tr '\n' ' ')); seed=$((seed+si))
    echo "after shuffling models:"
    printf -- "-cm %s " "${cmd1cmsArr[@]}"
    [ "${#cmd1rmsArr[@]}" -ne 0 ] && printf -- "-rm %s " "${cmd1rmsArr[@]}"; echo
    #
    cmdRev=$(echo "$cmd" | rev);
    lastCMrev=$(echo "${cmd1cmsArr[-1]}" | rev);
    if [ ${#cmd1rmsArr[@]} -gt 0 ]; then lastRMrev=$(echo "${cmd1rmsArr[-1]}" | rev); else lastRMrev=""; fi;
    #
    substrBeforeCMorRM=$(echo "$cmd" | awk '{ match($0, /(-cm|-rm)/); print substr($0, 1, RSTART-1) }');
    substrAfterCMandRM=$(echo "$cmd" | awk '{print $NF}'); # assuming that a RM or a CM is the last arg provided before the sequence file
    #
    cmd2cmsArr=($(echo "$cmd2" | grep -oE '\-cm [0-9:./]+' | sed 's/-cm//g' | sort -R --random-source=<(yes $seed) | tr '\n' ' ')); seed=$((seed+si))
    cmd2rmsArr=($(echo "$cmd2" | grep -oE '\-rm [0-9:./]+' | sed 's/-rm//g' | sort -R --random-source=<(yes $seed) | tr '\n' ' ')); seed=$((seed+si))
    printf -- "-cm %s " "${cmd2cmsArr[@]}"
    [ "${#cmd2rmsArr[@]}" -ne 0 ] && printf -- "-rm %s " "${cmd2rmsArr[@]}"; echo
    #
    echo "cmd1 has ${#cmd1cmsArr[@]} cms and ${#cmd1rmsArr[@]} rms"
    echo "cmd2 has ${#cmd2cmsArr[@]} cms and ${#cmd2rmsArr[@]} rms"
    #
    cmd2Rev=$(echo "$cmd2" | rev);
    lastCMrev2=$(echo "${cmd2cmsArr[-1]}" | rev);
    if [ ${#cmd2rmsArr[@]} -gt 0 ]; then lastRMrev2=$(echo "${cmd2rmsArr[-1]}" | rev); else lastRMrev2=""; fi;
    #
    substrBeforeCMorRM2=$(echo "$cmd2" | awk '{ match($0, /(-cm|-rm)/); print substr($0, 1, RSTART-1) }')
    substrAfterCMandRM2=$(echo "$cmd2" | awk '{print $NF}'); # assuming that a RM or a CM is the last arg provided before the sequence file
    #
    # choose model type
    if [ ${#cmd1rmsArr[@]} -eq 0 ] || [ ${#cmd2rmsArr[@]} -eq 0 ]; then 
        modelTypeArr=("cm")
    else
        modelTypeArr=("cm" "rm")
    fi
}
#
function ASSEMBLE_CHILD_CMDS() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ASSEMBLE "CHILDREN" COMMANDS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    #
    # convert cms array and rms array to cms string and rms string, respectively
    cmd1cmsArr=($(for i in ${cmd1cmsArr[@]}; do echo $i; done | sort))
    cms_str=$(printf "\055cm %s " ${cmd1cmsArr[@]});
    if [ ${#cmd1rmsArr[@]} -gt 0 ]; then
        cmd1rmsArr=($(for i in ${cmd1rmsArr[@]}; do echo $i; done | sort))
        rms_str=$(printf "\055rm %s " ${cmd1rmsArr[@]})
    else
        rms_str=""
    fi
    #
    cmd2cmsArr=($(for i in ${cmd2cmsArr[@]}; do echo $i; done | sort))
    cms_str2=$(printf "\055cm %s " ${cmd2cmsArr[@]});
    if [ ${#cmd2rmsArr[@]} -gt 0 ]; then
        cmd2rmsArr=($(for i in ${cmd2rmsArr[@]}; do echo $i; done | sort))
        rms_str=$(printf "\055rm %s " ${cmd2rmsArr[@]})
    else
        rms_str=""
    fi    
    #
    # commands after crossing
    cmd=$(echo $substrBeforeCMorRM $cms_str $rms_str $substrAfterCMandRM)
    cmd2=$(echo $substrBeforeCMorRM2 $cms_str2 $rms_str2 $substrAfterCMandRM2)
    printf "potential offspring (without -o arg):\n$cmd\n$cmd2\n"   
    #
    # add child cmd only if it's different from any adult cmd and child
    allUnsortedRes="${gaFolder}/eval/allUnsortedRes.tsv";
    cmd1SameAsParent=$(awk -F'\t' 'NR>2{print $NF}' $allUnsortedRes | grep -c "$cmd");
    if [ $cmd1SameAsParent -ne 0 ]; then
        echo "already executed: $cmd"
    elif [[ " ${childCmds[@]} " =~ "$cmd" ]]; then
        echo "already added as offspring: $cmd"
    else 
        echo "new offspring: $cmd";
        childCmds+=("$cmd");
    fi
    #
    cmd2SameAsParent=$(awk -F'\t' 'NR>2{print $NF}' $allUnsortedRes | grep -c "$cmd2");
    if [ $cmd2SameAsParent -ne 0 ]; then
        echo "already executed: $cmd2"
    elif [[ " ${childCmds[@]} " =~ "$cmd2" ]]; then
        echo "already added as offspring: $cmd2"
    else 
        echo "new offspring: $cmd2";
        childCmds+=("$cmd2");
    fi
}
#
### CROSSOVER FUNCTIONS ###############################################################################################
#
function XPOINT_CROSSOVER() {              
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ X-POINT CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # choose cross points indexes between idx 1 and size-2
    maxNumCrosspoints=2;
    numCrosspoints=$((RANDOM % $maxNumCrosspoints + 1));
    seed=$((seed+si)) && crossPointIdxs=( $( seq 1 $((numParamsPerModel-2)) | sort -R --random-source=<(yes $seed) | head -n $numCrosspoints | sort ) ); 
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
    elif [ $crossoverMasksum -eq $numParamsPerModel ]; then
        crossoverMask[$((RANDOM % ${#crossoverMask[@]}))]=0;
    fi
    #
    #
    echo "$numCrosspoints point crossover mask (cut indexes: ${crossPointIdxs[@]}) ---> ${crossoverMask[*]}";
    #
    for paramIdx in ${!crossoverMask[@]}; do
        if [ ${crossoverMask[$paramIdx]} -eq 1 ]; then
            # param ("gene") crossover itself
            temp=${p1modelArr[$paramIdx]};
            p1modelArr[$paramIdx]=${p2modelArr[$paramIdx]};
            p2modelArr[$paramIdx]=$temp;
        fi;
    done
}
#
function UNIFORM_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ UNIFORM CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    #
    # create mask
    crossoverMask=()
    for (( i=0; i < $numParamsPerModel; i++)); 
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
            temp=${p1modelArr[$paramIdx]};
            p1modelArr[$paramIdx]=${p2modelArr[$paramIdx]};
            p2modelArr[$paramIdx]=$temp;
        fi;
    done
}
#
function AVG_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ AVG CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    for paramIdx in ${!modelIsParamInt[@]}; do
        cmParam1=${p1modelArr[$paramIdx]} # parent 1
        cmParam2=${p2modelArr[$paramIdx]} # parent 2
        #
        # the avg of two params within integer domains must be integer
        if [ ${modelIsParamInt[$paramIdx]} -eq 1 ]; then 
            avgParam=$(echo "scale=0;($cmParam1+$cmParam2)/2" | bc);
        else # avg of two real nums
            avgParam=$(echo "scale=3;($cmParam1+$cmParam2)/2" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        fi
        #
        p1modelArr[$paramIdx]=$avgParam;
        #
        # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
        p2modelArr[$paramIdx]=$avgParam; 
    done
}
#
function DISCRETE_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DISCRETE CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # r=random.choice({x, y}), if r==0, childParam=p1Param; elif r==1, childParam=p2Param
    for paramIdx in $(seq 0 1 $((numParamsPerModel-1)) ); do
        cmParam1="${p1modelArr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${p2modelArr[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        # 
        cmParamChoices=( "$cmParam1" "$cmParam2" ); # chose param with idx=$paramIdx from either parent1 or parent2
        rndIdx=$((RANDOM % 2)); # random value taken from U(0,1)
        chosenCmParam=${cmParamChoices[$rndIdx]};
        #
        # one child may become duplicate of another, but if that is the case, then it is removed later in the script
        p1modelArr[$paramIdx]=$chosenCmParam;
        p2modelArr[$paramIdx]=${p1modelArr[$paramIdx]};
    done;
}
#
function FLAT_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ FLAT CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    for paramIdx in ${!modelIsParamInt[@]}; do
        cmParam1="${p1modelArr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${p2modelArr[$paramIdx]}"; # param with idx=$paramIdx from parent 2
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
            seed=$((seed+si)) && childParam=$( seq $cmParamMin 0.1 $cmParamMax | sort -R --random-source=<(yes $seed) | head -n 1 );
            #
            # round number to int if param type is int
            if [ ${modelIsParamInt[$paramIdx]} -eq 1 ]; then
                childParam=$(echo "($childParam+0.5)/1" | bc);
            fi
        fi
        #
        # one child may become duplicate of another, but if that is the case, then it is removed later in the script
        p1modelArr[paramIdx]=$childParam;
        p2modelArr[paramIdx]=${p1modelArr[paramIdx]};
    done
}
#
function HEURISTIC_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ HEURISTIC CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # formula to produces ONE child (per param) = p1 + random * ratio_weight * (p2 - p1)
    for paramIdx in ${!modelIsParamInt[@]}; do
        cmParam1="${p1modelArr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${p2modelArr[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        #
        alpha="0.$((RANDOM%999))";
        ratioWeight=1;
        #
        childParam1=$(echo "scale=3; $cmParam1 + $alpha * $ratioWeight * ($cmParam2 - $cmParam1)" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        childParam2=$(echo "scale=3; $cmParam2 + $alpha * $ratioWeight * ($cmParam1 - $cmParam2)" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        #
        if [ ${modelIsParamInt[$paramIdx]} -eq 1 ]; then # round value to int if params are int
            childParam1=$(echo "($childParam1+0.5)/1" | bc); 
            childParam2=$(echo "($childParam2+0.5)/1" | bc);
        fi
        #
        p1modelArr[$paramIdx1]=$childParam1;
        p2modelArr[$paramId2]=$childParam2;
    done
}
#
### MUTATION FUNCTIONS ###############################################################################################
#
function DEFINE_PARAM_RANGES() {
  if $hm; then # heuristic mutation
    #
    # CM PARAMETERS
    # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
    NB_C_cm_lst=( {1..13} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( 1 2 5 10 20 50 100 200 500 1000 2000 ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_I_cm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_G_cm_lst=( $(seq 0.05 0.05 0.95) ) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..6} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_E_lst=( 1 2 5 10 20 50 100 ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a STCM
    NB_A_lst=($(seq 0.1 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of RMs
    NB_C_rm_lst=(12 13 14) # RM size. higher values -> more RAM -> better compression
    NB_B_lst=($(seq 0.05 0.05 0.95)) # (real (0;1]) beta. discards or keeps a RM
    NB_L_lst=( {1..14} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=( $(seq 0.05 0.05 0.95) ) # (real [0;1)) gamma; decayment forgetting factor
    NB_I_rm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_W_lst=( $(seq 0.01 0.05 0.99) ) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=( $(seq 1 1 5) ) # (integer {0}, [1;50]) max cache size
  else
    #
    # CM PARAMETERS
    # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
    NB_C_cm_lst=( {1..12} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( {1..5000} ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_I_cm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_G_cm_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..20} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_E_lst=( {1..5000} ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a STCM
    NB_A_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_R_rm_lst=( {1..500} ) # (integer [1;10000]) max num of RMs
    NB_C_rm_lst=( {1..13} ) # RM size. higher values -> more RAM -> better compression
    NB_B_lst=($(seq 0.01 0.01 0.99)) # (real (0;1]) beta. discards or keeps a RM
    NB_L_lst=( {2..20} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma; decayment forgetting factor
    NB_I_rm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_W_lst=( $(seq 0.01 0.01 0.99) ) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=( $(seq 0 1 5) ) # (integer {0}, [1;50]) max cache size
  fi
}
#
###############################################################################################
#
# used in average crossover, intermediate crossover
# a cm "chromosome" has 6 integer "genes" (1) and 2 real "genes" (0)
CMisParamInt=( 1 1 1 0 1 1 1 0 )
#
# a rm "chromosome" has 5 integer "genes" (1) and 3 real "genes" (0)
RMisParamInt=( 1 1 0 1 0 1 0 1 )
#
# probability of a pair of cmds in becoming parents
cmdCR=0.6;
# 
# probability of a pair of models (excluding first model pair of a model type (either cm or rm), which must crossover) producing offspring chromosome, given that their respective pair of cmds will crossover
modelCR=0.6;
#
# probability of a cmd being mutated, given that crossover has previously occured
cmdMR=0.1;
#
# probability of each parameter of each model of a cmd (excluding parameters of a first model pair of a model type (either cm or rm), with must mutate) being mutated, given that the cmd will mutate
paramMR=0.1;
#
cmdCrossoverOp="cmga"; # canonical metameric GA
crossoverOp="xpoint";
#
# number of parent cmds per crossover
numCmds=2;
#
# heuristic mutation
hm=false
#
configJson="../config.json"
#
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
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
    # choose command crossover operator
    -cc|--command-crossover)
        cmdCrossoverOp="$2";
        shift 2;
        ;;
    # choose model crossover operator
    -c|-x|--crossover|--cover|--xover)
        crossoverOp="$2";
        shift 2;
        ;;
    -cr|-ccr|--cmd-crossover-rate|--command-crossover-rate|--individual-crossover-rate|--genome-crossover-rate)
        cmdCR=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    -mcr|--model-crossover-rate|--chromossome-crossover-rate)
        modelCR=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    -mr|-cmr|--cmd-mut-rate|--cmd-mutation-rate|--command-mutation-rate|--individual-mutation-rate|--genome-mutation-rate)
        cmdMR=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    -pmr|--param-mut-rate|--param-mutation-rate|--parameter-mutation-rate)
        paramMR=$(echo "scale=3; $2" | bc);
        shift 2;
        ;;
    --heuristic-mutation|-hm)
        hm=true
        shift
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
DEFINE_PARAM_RANGES;
#
if [ ${#SEQUENCES[@]} -eq 0 ]; then
  SEQUENCES=( "${ALL_SEQUENCES[@]}" );
fi
#
echo "${SEQUENCES[@]}"
for sequenceName in "${SEQUENCES[@]}"; do
    ds=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    #
    gaFolder="../${ds}/$ga";
    selCmdsFile="$gaFolder/sel/selectedCmds.txt";
    selCmdsFilesArr+=( $( ls $selCmdsFile) );
    #
    echo "cmds files input: ";
    printf "%s\n" ${selCmdsFilesArr[@]}; 
done
# 
for selCmdsFile in ${selCmdsFilesArr[@]}; do
    #
    gaFolder="../${ds}/$ga";
    nextGen=$((gnum+1));
    cmdsFileOutput="$gaFolder/g$nextGen.sh";
    GET_SEED
    #
    echo "========================================================";
    echo "=== SEL CMDS FILE INPUT: $selCmdsFile ====";
    echo "=== CHILD CMDS FILE OUTPUT: $cmdsFileOutput ==============";
    echo "========================================================";
    #
    # sort selected cmds by num of RMs, then num of CMs
    # sorting by num of RMs is more important than sorting by num of CMs because RMs are more influential on sequence compression 
    awk '{cm_num=gsub(/-cm/, "&"); rm_num = gsub(/-rm/, "&"); print rm_num"\t"cm_num"\t"$0}' $selCmdsFile | sort | awk -F'\t' '{print $NF}' > tmp
    cat tmp > $selCmdsFile
    rm -fr tmp
    #
    # selected cmds
    chosenCmds=();
    while IFS= read -r selCmd; do
        chosenCmds+=("${selCmd}");
    done < <( cat $selCmdsFile );     
    #
    echo "num chosen cmds: ${#chosenCmds[@]}";
    coupleNum=$((coupleNum+1))
    #
    # iterate through each pair of cmds
    while [ "${#chosenCmds[@]}" -gt 1 ]; do  
        echo "=========================== "${#chosenCmds[@]}" CMDS TO GO =====================================";
        #
        cmd="${chosenCmds[0]}";
        cmd2="${chosenCmds[1]}";
        #
        echo "raw commands randomly chosen for crossover";
        echo ${cmd[@]}; 
        echo ${cmd2[@]};
        #
        # COMMAND CROSSOVER ================================================
        #
        rndFloat="0.$((RANDOM%999))";
        if (( $(echo "$rndFloat <= $cmdCR" | bc) )); then
            #
            crossNum=$((crossNum+1))
            echo "============= $rndFloat <= $cmdCR --> CMD CROSSOVER NUMBER $crossNum ====================================="
            #
            DISASSEMBLE_PARENT_CMDS
            #
            # in each crossover there should be at least one crossover between two models of one type
            modelTypeMandatoryCrossover="${modelTypeArr[$RANDOM%${#modelTypeArr[@]}]}"
            #
            # loop through each model type of a pair of cmds
            for modelType in "${modelTypeArr[@]}"; do
                #
                # get models of a certain type from each parent
                [ "$modelType" = "cm" ] && p1modelsArr=( "${cmd1cmsArr[@]}" ) || p1modelsArr=( "${cmd1rmsArr[@]}" ) 
                [ "$modelType" = "cm" ] && p2modelsArr=( "${cmd2cmsArr[@]}" ) || p2modelsArr=( "${cmd2rmsArr[@]}" )
                [ "$modelType" = "cm" ] && modelIsParamInt=( "${CMisParamInt[@]}" ) || modelIsParamInt=( "${RMisParamInt[@]}" ) 
                #
                # calculate number of model pairs
                if [ "$crossoverOp" = "cmga" ] || [ "$crossoverOp" = "1" ]; then
                    #
                    # num of model pairs equals the parent with the fewest models of a certain type
                    [ "${#p1modelsArr[@]}" -lt "${#p2modelsArr[@]}" ] && numModelPairs="${#p1modelsArr[@]}" || numModelPairs="${#p2modelsArr[@]}"
                else
                    if [ "${#p1modelsArr[@]}" -lt "${#p2modelsArr[@]}" ] ; then 
                        minPairs="${#p1modelsArr[@]}"
                        maxPairs="${#p2modelsArr[@]}"
                    else
                        minPairs="${#p2modelsArr[@]}"
                        maxPairs="${#p1modelsArr[@]}"
                    fi
                    numModelPairs=$((RANDOM%(maxPairs-minPairs+1)+minPairs))
                fi
                #
                # iterate through each model pair (one model from first cmd, the other model from second cmd) for potential crossover
                for modelIdx in $( seq 0 $((numModelPairs-1)) ); do
                    #
                    # first chosen pair of models MUST crossover, assuming they match the mandatory model type 
                    # example: 
                    # p1: CM1 CM2 CM3 RM1 RM2 RM3
                    # p2: CM1         RM1 RM2
                    # in canonical metameric crossover, either CM1 pair or RM1 pair MUST apply a model crossover operator
                    # in random metameric crossover, the first pair of either CM or RM MUST apply a model crossover operator
                    ((! $modelIdx)) && [ "$modelType" = "$modelTypeMandatoryCrossover" ] && mandatoryPair=true || mandatoryPair=false
                    #
                    if [ "$crossoverOp" = "cmga" ] || [ "$crossoverOp" = "1" ]; then
                        modelIdx1=$modelIdx
                        modelIdx2=$modelIdx
                    else
                        modelIdx1=$((RANDOM%numModelPairs))
                        modelIdx2=$((RANDOM%numModelPairs))
                    fi
                    #
                    # get model pair as strings
                    p1model="${p1modelsArr[modelIdx1]}"
                    p2model="${p2modelsArr[modelIdx2]}"
                    echo "$modelType selected from cmd1 before crossover (str) ---> $p1model (index $modelIdx1)";
                    echo "$modelType selected from cmd2 before crossover (str) ---> $p2model (index $modelIdx2)";
                    #
                    # transform model pair strings into arrays
                    p1modelArr=($(echo "${p1modelsArr[modelIdx1]}" | sed 's/[:/]/ /g'));
                    p2modelArr=($(echo "${p2modelsArr[modelIdx2]}" | sed 's/[:/]/ /g'));
                    #
                    # get num of params per model
                    [ "${#p1modelsArr[@]}" -lt "${#p2modelsArr[@]}" ] && numParamsPerModel="${#p1modelArr[@]}" || numParamsPerModel="${#p2modelArr[@]}"
                    #
                    # crossover operator is applied if random number does not surpass model crossover rate
                    rndFloat="0.$((RANDOM%999))";
                    if (( $(echo "$rndFloat <= $modelCR" | bc) )) || $mandatoryPair; then 
                        (( $(echo "$rndFloat <= $modelCR" | bc) )) && echo "$rndFloat <= $modelCR --> model crossover" || echo "$modelType with idxs $modelIdx1 and $modelIdx2 MUST crossover"
                        if [ "$crossoverOp" = "xpoint" ] || [ "$crossoverOp" = "xp" ] || [ "$crossoverOp" = "x" ]; then
                            XPOINT_CROSSOVER;
                        elif [ "$crossoverOp" = "uniform" ] || [ "$crossoverOp" = "u" ]; then
                            UNIFORM_CROSSOVER;
                        elif [ "$crossoverOp" = "average" ] || [ "$crossoverOp" = "avg" ] || [ "$crossoverOp" = "a" ]; then
                            AVG_CROSSOVER;
                        elif [ "$crossoverOp" = "discrete" ] || [ "$crossoverOp" = "d" ]; then
                            DISCRETE_CROSSOVER;
                        elif [ "$crossoverOp" = "flat" ] || [ "$crossoverOp" = "f" ]; then
                            FLAT_CROSSOVER;
                        elif [ "$crossoverOp" = "heuristic" ] || [ "$crossoverOp" = "h" ]; then
                            HEURISTIC_CROSSOVER;
                        fi
                    else 
                        echo "$rndFloat > $modelCR --> no model crossover"
                    fi
                    #
                    # convert model arrays of parent 1 to strings
                    p1model=$(printf "%s:" ${p1modelArr[@]});
                    p1model="${p1model%:}";
                    [ "$modelType" = "cm" ] && p1model=$(echo "$p1model" | sed 's/:/\//4');
                    echo "$modelType selected from cmd1 after crossover (str) ---> $p1model (index $modelIdx1)";
                    #
                    # convert model arrays of parent 2 to strings
                    p2model=$(printf "%s:" ${p2modelArr[@]});
                    p2model="${p2model%:}";
                    [ "$modelType" = "cm" ] && p2model=$(echo "$p2model" | sed 's/:/\//4');
                    echo "$modelType selected from cmd2 after crossover (str) ---> $p2model (index $modelIdx2)";
                    #
                    # for each cmd, replace old model with child model
                    p1modelsArr[$modelIdx1]="$p1model";
                    p2modelsArr[$modelIdx2]="$p2model";
                    #
                    echo "$modelType arr after crossover: ${p1modelsArr[@]}";
                    echo "$modelType arr 2 after crossover: ${p2modelsArr[@]}";
                    #
                    [ "$modelType" = "cm" ] && cmd1cmsArr=("${p1modelsArr[@]}") || cmd1rmsArr=("${p1modelsArr[@]}")
                    [ "$modelType" = "cm" ] && cmd2cmsArr=("${p2modelsArr[@]}") || cmd2rmsArr=("${p2modelsArr[@]}")
                done
            done
            #
            # COMMAND MUTATION (only happens if crossover occured) ================================================
            #
            # iterate through each cmd in the pair of parents
            for chosenCmd in $(seq 1 $numCmds); do
                #
                # in each mutation there should be at least one mutation in at least one param of a model of a choosen type
                modelTypeMandatoryMutation="${modelTypeArr[$RANDOM%${#modelTypeArr[@]}]}"
                #
                rndFloat="0.$((RANDOM%999))"
                if (( $(echo "$rndFloat <= $cmdMR" | bc) )); then
                    echo "$rndFloat <= $cmdMR --> child cmd$chosenCmd mutation"
                    echo "============= CHILD MUTATION =====================================";
                    #
                    # loop through each model type of a child cmd that will be mutated
                    for modelType in "${modelTypeArr[@]}"; do
                        #
                        # get models of a certain type from child
                        if [ "$chosenCmd" -eq 1 ]; then
                            [ "$modelType" = "cm" ] && pModelsArr=( "${cmd1cmsArr[@]}" ) || pModelsArr=( "${cmd1rmsArr[@]}" ) 
                        elif [ "$chosenCmd" -eq 2 ]; then
                            [ "$modelType" = "cm" ] && pModelsArr=( "${cmd2cmsArr[@]}" ) || pModelsArr=( "${cmd2rmsArr[@]}" )
                        fi
                        #
                        [ "$modelType" = "cm" ] && modelIsParamInt=( "${CMisParamInt[@]}" ) || modelIsParamInt=( "${RMisParamInt[@]}" ) 
                        #
                        numModelsOfAtype="${#pModelsArr[@]}"
                        for modelIdx in $(seq 0 $((numModelsOfAtype-1))); do
                            model="${pModelsArr[$modelIdx]}";
                            echo "$modelType from cmd$(($chosenCmd)) b4 mutation (str) ----> $model (index $modelIdx)"
                            #
                            # convert model string to array of parameters
                            modelParamsArr=($(echo "$model" | sed 's/[:/]/ /g')); 
                            #
                            # mutation mask
                            mutationMask=($(for i in $(seq 1 $numParamsPerModel); do echo "$paramMR"; done))
                            if [ $modelIdx -eq 0 ] && [ "$modelType" = "$modelTypeMandatoryMutation" ]; then
                                rndMutIdx=$((RANDOM%$numParamsPerModel))
                                mutationMask[rndMutIdx]=1
                            fi
                            echo "model mutation mask --------------------------------> ${mutationMask[*]}"
                            #
                            for paramIdx in ${!mutationMask[@]}; do
                                rndFloat="0.$((RANDOM%999))"
                                maskParamMR=${mutationMask[paramIdx]}
                                if (( $(echo "$rndFloat <= $maskParamMR" | bc) )); then
                                    #
                                    # guarantees that mutation changes a value to a different value
                                    while true; do 
                                        #
                                        # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]
                                        if [ "$modelType" = "cm" ]; then 
                                            mutationVals=( 
                                                ${NB_C_cm_lst[$((RANDOM % ${#NB_C_cm_lst[@]}))]}
                                                ${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}
                                                ${NB_I_cm_lst[$((RANDOM % ${#NB_I_cm_lst[@]}))]}
                                                ${NB_G_cm_lst[$((RANDOM % ${#NB_G_cm_lst[@]}))]}
                                                #
                                                ${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]}
                                                ${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]}
                                                ${NB_R_cm_lst[$((RANDOM % ${#NB_R_cm_lst[@]}))]}
                                                ${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]}
                                            );
                                        else
                                            mutationVals=(
                                                ${NB_R_rm_lst[$((RANDOM % ${#NB_R_rm_lst[@]}))]}
                                                ${NB_C_rm_lst[$((RANDOM % ${#NB_C_rm_lst[@]}))]}
                                                ${NB_B_lst[$((RANDOM % ${#NB_B_lst[@]}))]}
                                                ${NB_L_lst[$((RANDOM % ${#NB_L_lst[@]}))]}
                                                #
                                                ${NB_G_rm_lst[$((RANDOM % ${#NB_G_rm_lst[@]}))]}
                                                ${NB_I_rm_lst[$((RANDOM % ${#NB_I_rm_lst[@]}))]}
                                                ${NB_W_lst[$((RANDOM % ${#NB_W_lst[@]}))]}
                                                ${NB_Y_lst[$((RANDOM % ${#NB_Y_lst[@]}))]}
                                            );
                                        fi
                                        #
                                        if (( $(echo "${modelParamsArr[$paramIdx]} != ${mutationVals[$paramIdx]}"|bc) )); then  
                                            echo "$rndFloat <= $maskParamMR --> mutation on parameter with idx $paramIdx from ${modelParamsArr[$paramIdx]} to ${mutationVals[$paramIdx]}"
                                            modelParamsArr[$paramIdx]=${mutationVals[$paramIdx]} # mutate parameter
                                            break
                                        fi
                                    done
                                fi;
                            done
                            #
                            # convert params arr to str
                            modelParamsStr="$(printf "%s:" ${modelParamsArr[@]})" # x:x:x:x:x:x:x:x:
                            modelParamsStr="${modelParamsStr%:}" # x:x:x:x:x:x:x:x
                            [ "$modelType" = "cm" ] && modelParamsStr="$(echo "$modelParamsStr" | sed 's/:/\//4')" # x:x:x:x/x:x:x:x
                            echo "$modelType from cmd$chosenCmd after mutation (str) -> $modelParamsStr"
                        done
                        #
                        # updated array of models of a certain type with mutated params
                        if [ $chosenCmd -eq 1 ]; then
                            p1modelsArr[$modelIdx]=$modelParamsStr;
                            echo "$modelType models from cmd1 after mutation: ${p1modelsArr[@]}";
                        else 
                            p2modelsArr[$modelIdx]=$modelParamsStr;
                            echo "$modelType models from cmd2 after mutation: ${p2modelsArr[@]}";
                        fi;
                    done
                else 
                    echo "$rndFloat > $cmdMR --> no command mutation"
                fi
            done
            #
            ASSEMBLE_CHILD_CMDS
        else 
            echo "$rndFloat > $cmdCR --> no cmd crossover"
        fi
        #
        # pops the 2 first elements of the selected cmds array
        chosenCmds=("${chosenCmds[@]:2}");
    done
    #
    # write "child" commands into output cmds file
    echo "=========================== OFFSPRING CMDS =====================================";
    printf "%s \n" "${childCmds[@]}";
    echo "Number of child cmds: ${#childCmds[@]}";
    ( for child in "${childCmds[@]}"; do
        echo "$child";
    done ) > $cmdsFileOutput;
    #
    # allow execution of script where commands have just been written to
    chmod +x $cmdsFileOutput;
    #
    # don't remove script even if it's empty due to no offspring
    if [ ${#childCmds[@]} -eq 0 ]; then
        dsX=$(echo "$selCmdsFile" | awk -F 'DS|/' '{print $3}');
        echo "NO NEW OFFSPRING - POPULATION STAGNATION OF DS${dsX}";
        exit 1;
    fi
    #
    SAVE_SEED
done
