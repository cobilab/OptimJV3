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
function DISASSEMBLE_PARENT_CMDS() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DISSASSEMBLE "PARENT" COMMANDS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
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
    echo "cms_arr has ${#cms_arr[@]} models"
    echo "cms_arr2 has ${#cms_arr2[@]}  models"
    echo "rms_arr has ${#rms_arr[@]} models"
    echo "rms_arr2 has ${#rms_arr2[@]}  models"
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
    # choose model type
    if [ ${#rms_arr[@]} -eq 0 ] || [ ${#rms_arr2[@]} -eq 0 ]; then 
        modelTypeArr=("cm")
    else
        modelTypeArr=("cm" "rm")
    fi
}
#
function ASSEMBLE_CHILD_CMDS() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DISSASSEMBLE "CHILDREN" COMMANDS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
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
    allRawRes="${gaFolder}/*allRawRes.tsv";
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
}
#
### CROSSOVER FUNCTIONS ###############################################################################################
#
function XPOINT_CROSSOVER() {              
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ X-POINT CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # choose cross points indexes
    maxNumCrosspoints=2;
    numCrosspoints=$((RANDOM % $maxNumCrosspoints + 1));
    seed=$((seed+si)) && crossPointIdxs=( $( seq 0 1 $((NUM_PARAMS_PER_MODEL-1)) | sort -R --random-source=<(yes $seed) | head -n $numCrosspoints | sort ) ); 
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
            temp=${model_params_arr[$paramIdx]};
            model_params_arr[$paramIdx]=${model_params_arr2[$paramIdx]};
            model_params_arr2[$paramIdx]=$temp;
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
            temp=${model_params_arr[$paramIdx]};
            model_params_arr[$paramIdx]=${model_params_arr2[$paramIdx]};
            model_params_arr2[$paramIdx]=$temp;
        fi;
    done
}
#
function AVG_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ AVG CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    for paramIdx in ${!MODEL_IS_PARAM_INT[@]}; do
        cmParam1=${model_params_arr[$paramIdx]} # parent 1
        cmParam2=${model_params_arr2[$paramIdx]} # parent 2
        #
        # the avg of two params within integer domains must be integer
        if [ ${MODEL_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then 
            avgParam=$(echo "scale=0;($cmParam1+$cmParam2)/2" | bc);
        else # avg of two real nums
            avgParam=$(echo "scale=3;($cmParam1+$cmParam2)/2" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        fi
        #
        model_params_arr[$paramIdx]=$avgParam;
        #
        # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
        model_params_arr2[$paramIdx]=$avgParam; 
    done
}
#
function DISCRETE_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DISCRETE CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # r=random.choice({x, y}), if r==0, childParam=p1Param; elif r==1, childParam=p2Param
    for paramIdx in $(seq 0 1 $((NUM_PARAMS_PER_MODEL-1)) ); do
        cmParam1="${model_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${model_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        # 
        cmParamChoices=( "$cmParam1" "$cmParam2" ); # chose param with idx=$paramIdx from either parent1 or parent2
        rndIdx=$((RANDOM % 2)); # random value taken from U(0,1)
        chosenCmParam=${cmParamChoices[$rndIdx]};
        #
        # one child may become duplicate of another, but if that is the case, then it is removed later in the script
        model_params_arr[$paramIdx]=$chosenCmParam;
        model_params_arr2[$paramIdx]=${model_params_arr[$paramIdx]};
    done;
}
#
function FLAT_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ FLAT CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    for paramIdx in ${!MODEL_IS_PARAM_INT[@]}; do
        cmParam1="${model_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${model_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
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
            if [ ${MODEL_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then
                childParam=$(echo "scale=0; $childParam/1" | bc);
            fi
        fi
        #
        # one child may become duplicate of another, but if that is the case, then it is removed later in the script
        model_params_arr[paramIdx]=$childParam;
        model_params_arr2[paramIdx]=${model_params_arr[paramIdx]};
    done
}
#
function HEURISTIC_CROSSOVER() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ HEURISTIC CROSSOVER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    # formula to produces ONE child (per param) = p1 + random * ratio_weight * (p2 - p1)
    for paramIdx in ${!MODEL_IS_PARAM_INT[@]}; do
        cmParam1="${model_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
        cmParam2="${model_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
        #
        randomNum="0.$((RANDOM%999))";
        ratioWeight=1;
        #
        childParam=$(echo "scale=3; $cmParam1 + $randomNum * $ratioWeight * ($cmParam2 - $cmParam1)" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
        #
        if [ ${MODEL_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then # round value to int if params are int
            childParam=$(echo "scale=0; $childParam/1" | bc);
        fi
        #
        model_params_arr[$paramIdx]=$childParam;
        #
        # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
        model_params_arr2[$paramIdx]=$childParam;
    done
}
#
### MUTATION FUNCTIONS ###############################################################################################
#
function DEFINE_PARAM_RANGES() {
  if $kbm; then # knowledge-based mutation
    #
    # CM PARAMETERS
    # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
    NB_C_cm_lst=( {1..13} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( 1 2 5 10 20 50 100 200 500 1000 2000 ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_I_cm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_G_cm_lst=( $(seq 0.05 0.05 0.95) ) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..6} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant ga (stcm?)
    NB_E_lst=( 1 2 5 10 20 50 100 ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_A_lst=($(seq 0.1 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_C_rm_lst=(12 13 14) # RM size. higher values -> more RAM -> better compression
    NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of repeat gas
    NB_B_lst=($(seq 0.05 0.05 0.95)) # (real (0;1]) beta. discards or keeps a repeat ga
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
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant ga (stcm?)
    NB_E_lst=( {1..5000} ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_A_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_R_rm_lst=( {1..500} ) # (integer [1;10000]) max num of repeat gas
    NB_C_rm_lst=( {1..13} ) # RM size. higher values -> more RAM -> better compression
    NB_B_lst=($(seq 0.01 0.01 0.99)) # (real (0;1]) beta. discards or keeps a repeat ga
    NB_L_lst=( {2..20} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma; decayment forgetting factor
    NB_I_rm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_W_lst=( $(seq 0.01 0.01 0.99) ) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=( $(seq 0 1 5) ) # (integer {0}, [1;50]) max cache size
  fi
}
#
function MUTATION() {
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ MUTATION ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~";
    #
    chosenCmd=$(( RANDOM % $numCmds )); # choose command where mutation will occur
    if [ $chosenCmd -eq 0 ]; then
        chosenModelIdx=$(( RANDOM % ${#model_arr[@]} ));
        chosenModel="${model_arr[$chosenModelIdx]}"; # choose model where mutation will occur (str)
    else 
        chosenModelIdx=$(( RANDOM % ${#model_arr2[@]} ));
        chosenModel="${model_arr2[$chosenModelIdx]}"; # choose model where mutation will occur (str)
    fi;
    echo "chosen $modelType from command$(($chosenCmd+1)) b4 mutation (str) ----> $chosenModel (index $chosenModelIdx)"
    #
    chosenModelParamsArr=($(echo "$chosenModel" | sed 's/[:/]/ /g')); # model where mutation will occur (arr)
    #
    # ${model_arr[@]} ${model_arr2[@]}
    # create mutation mask
    mutationMask=(0 0 0 0 0 0 0 0);
    rndMutIdx=$((RANDOM%$NUM_PARAMS_PER_MODEL))
    mutationMask[rndMutIdx]=1
    #
    echo "mutation mask --------------------------------> ${mutationMask[*]}"
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
    for paramIdx in ${!mutationMask[@]}; do
        if [ ${mutationMask[$paramIdx]} -eq 1 ]; then
            chosenModelParamsArr[$paramIdx]=${mutationVals[$paramIdx]}; # mutation itself
        fi;
    done;
    #
    # convert params arr to str
    chosenModelParamsStr="$(printf "%s:" ${chosenModelParamsArr[@]})"; # x:x:x:x:x:x:x:x:
    chosenModelParamsStr="${chosenModelParamsStr%:}"; # x:x:x:x:x:x:x:x
    [ "$modelType" = "cm" ] && chosenModelParamsStr="$(echo "$chosenModelParamsStr" | sed 's/:/\//4')"; # x:x:x:x/x:x:x:x
    echo "chosen $modelType from command$(($chosenCmd+1)) after mutation (str) -> $chosenModelParamsStr"
    #
    # chosen model arr for mutation ---> updated model arr with model that has been mutated in a param
    if [ $chosenCmd -eq 0 ]; then
        model_arr[$chosenModelIdx]=$chosenModelParamsStr;
    else 
        model_arr2[$chosenModelIdx]=$chosenModelParamsStr;
    fi;
}
#
###############################################################################################
#
DEFINE_PARAM_RANGES;
#
# each chromosome has always 8 genes
NUM_PARAMS_PER_MODEL=8;
#
# used in average crossover, intermediate crossover
# a cm "chromosome" has 6 integer "genes" (1) and 2 real "genes" (0)
CM_IS_PARAM_INT=( 1 1 1 0 1 1 1 0 )
#
# a rm "chromosome" has 5 integer "genes" (1) and 3 real "genes" (0)
RM_IS_PARAM_INT=( 1 1 0 1 0 1 0 1 )
#
CROSSOVER_RATE=0.6; # probability of a pair (or set) of cmds in becoming parents
MUTATION_RATE=0.17; # probability of mutation occuring in each cmd; mutation cannot happen without crossover
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
DEFAULT_SEED=1;
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
    # xpoint, uniform
    --crossover|--xover|-x|-c)
        CROSSOVER_OP="$2";
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
    --knowledge-based-mutation|-kbm)
        kbm=true
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
    #
    echo "========================================================";
    echo "=== SEL CMDS FILE INPUT: $selCmdsFile ====";
    echo "=== CHILD CMDS FILE OUTPUT: $cmdsFileOutput ==============";
    echo "========================================================";
    #
    # selected cmds
    chosenCmds=();
    while IFS= read -r selCmd; do
        chosenCmds+=("${selCmd}");
    done < <( cat $selCmdsFile );     
    #
    echo "num chosen cmds: ${#chosenCmds[@]}";
    coupleNum=$((coupleNum+1))
    while [ "${#chosenCmds[@]}" -gt 0 ]; do  
        echo "=========================== "${#chosenCmds[@]}" CMDS TO GO =====================================";
        #
        command="${chosenCmds[0]}";
        command2="${chosenCmds[1]}";
        #
        echo "raw commands randomly chosen for crossover";
        echo ${command[@]}; 
        echo ${command2[@]};
        #
        # CROSSOVER ##########################################################################################################################
        #
        rndFloat="0.$((RANDOM%999))";
        if (( $(echo "$rndFloat <= $CROSSOVER_RATE" | bc) )); then 
            echo "$rndFloat <= $CROSSOVER_RATE --> crossover"
            crossMutRepetitions=$((RANDOM%3+1))
            crossMutNum=$((crossMutNum+1))
            #
            echo "=========================== CROSSOVER AND MUTATION NUMBER $crossMutNum WILL REPEAT $crossMutRepetitions TIMES =====================================";
            #
            DISASSEMBLE_PARENT_CMDS
            #
            for i in $(seq 1 $crossMutRepetitions); do
                #
                modelTypeArrLen="${#modelTypeArr[@]}"
                rndModelTypeIdx=$((RANDOM%modelTypeArrLen))
                modelType="${modelTypeArr[rndModelTypeIdx]}"
                echo "chosen model type: $modelType"
                #
                [ "$modelType" = "cm" ] && model_arr=( "${cms_arr[@]}" ) || model_arr=( "${rms_arr[@]}" ) 
                [ "$modelType" = "cm" ] && model_arr2=( "${cms_arr2[@]}" ) || model_arr2=( "${rms_arr2[@]}" )
                [ "$modelType" = "cm" ] && MODEL_IS_PARAM_INT=( "${CM_IS_PARAM_INT[@]}" ) || MODEL_IS_PARAM_INT=( "${RM_IS_PARAM_INT[@]}" ) 
                #
                # choose model indexes where crossover will happen
                chosen_model_idx=$(( RANDOM % ${#model_arr[@]} ));
                chosen_model_idx2=$(( RANDOM % ${#model_arr2[@]} ));
                #
                echo "chosen $modelType from cmd1 before crossover (str) ---> " "${model_arr[chosen_model_idx]}" " (index " $chosen_model_idx ")";
                echo "chosen $modelType from cmd2 before crossover (str) ---> " "${model_arr2[chosen_model_idx2]}" " (index " $chosen_model_idx2 ")";
                #
                # each chosen cm is transformed into an array of 8 parameters ("genes")
                model_params_arr=($(echo "${model_arr[chosen_model_idx]}" | sed 's/[:/]/ /g'));
                model_params_arr2=($(echo "${model_arr2[chosen_model_idx2]}" | sed 's/[:/]/ /g'));
                #
                if [ "$CROSSOVER_OP" = "xpoint" ] || [ "$CROSSOVER_OP" = "xp" ] || [ "$CROSSOVER_OP" = "x" ]; then
                    XPOINT_CROSSOVER;
                elif [ "$CROSSOVER_OP" = "uniform" ] || [ "$CROSSOVER_OP" = "u" ]; then
                    UNIFORM_CROSSOVER;
                elif [ "$CROSSOVER_OP" = "average" ] || [ "$CROSSOVER_OP" = "avg" ] || [ "$CROSSOVER_OP" = "a" ]; then
                    AVG_CROSSOVER;
                elif [ "$CROSSOVER_OP" = "discrete" ] || [ "$CROSSOVER_OP" = "d" ]; then
                    DISCRETE_CROSSOVER;
                elif [ "$CROSSOVER_OP" = "flat" ] || [ "$CROSSOVER_OP" = "f" ]; then
                    FLAT_CROSSOVER;
                elif [ "$CROSSOVER_OP" = "heuristic" ] || [ "$CROSSOVER_OP" = "h" ]; then
                    HEURISTIC_CROSSOVER;
                fi
                #
                # convert param arrs to strs
                model_params_str=$(printf "%s:" ${model_params_arr[@]});
                model_params_str="${model_params_str%:}";
                [ "$modelType" = "cm" ] && model_params_str=$(echo "$model_params_str" | sed 's/:/\//4');
                echo "chosen $modelType from cmd1 after crossover (str) ----> " $model_params_str
                #
                model_params_str2=$(printf "%s:" ${model_params_arr2[@]});
                model_params_str2="${model_params_str2%:}";
                [ "$modelType" = "cm" ] && model_params_str2=$(echo "$model_params_str2" | sed 's/:/\//4');
                echo "chosen $modelType from cmd2 after crossover (str) ----> " $model_params_str2
                # 
                # replace models chosen for crossover with updated cms
                model_arr[$chosen_model_idx]=$model_params_str;
                model_arr2[$chosen_model_idx2]=$model_params_str2;
                #
                echo "$modelType arr after crossover: ${model_arr[@]}";
                echo "$modelType arr 2 after crossover: ${model_arr2[@]}";
                #
                rndMutNum="0.$((RANDOM%999))"
                if (( $(echo "$rndMutNum <= $MUTATION_RATE" | bc) )); then
                    echo "$rndMutNum <= $MUTATION_RATE --> mutation"
                    MUTATION
                    echo "$modelType arr after mutation: ${model_arr[@]}";
                    echo "$modelType arr2 after mutation: ${model_arr2[@]}";
                else 
                    echo "$rndMutNum > $MUTATION_RATE --> no mutation"
                fi
                #
                [ "$modelType" = "cm" ] && cms_arr=("${model_arr[@]}") || rms_arr=("${model_arr[@]}")
                [ "$modelType" = "cm" ] && cms_arr2=("${model_arr2[@]}") || rms_arr2=("${model_arr2[@]}")
            done
            #
            ASSEMBLE_CHILD_CMDS
        else 
            echo "$rndFloat > $CROSSOVER_RATE --> no crossover"
        fi
        #
        # pops the 2 first elements of the selected cmds array
        chosenCmds=("${chosenCmds[@]:2}");
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
        dsX=$(echo "$selCmdsFile" | awk -F 'DS|/' '{print $3}');
        echo "NO NEW OFFSPRING - POPULATION STAGNATION OF DS${dsX}";
        exit 1;
    fi
done
