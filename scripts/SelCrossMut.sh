#!/usr/bin/env bash
#
# these lists help to know how to mutate in a valid way
# 
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
NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant model on STCM
NB_A_lst=($(seq 0 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
#
# RM PARAMETERS - these arrs are used in mutation
# -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
NB_C_rm_lst=(12 13) # RM size. higher values -> more RAM -> better compression
NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of repeat models
NB_B_lst=($(seq 0.5 0.1 0.9)) # (real (0;1]) beta. discards or keeps a repeat model
NB_L_lst=( {4..9} ) # (integer (1;20]) limit threshold; has dependency with NB_B
NB_G_rm_lst=(0.7) # (real [0;1)) gamma; decayment forgetting factor
NB_W_lst=(0.06) # (real (0;1)) initial weight for repeat classes
NB_Y_lst=(2) # (integer {0}, [1;50]) max cache size
#
NUM_PARAMS_PER_MODEL=8;
#
# used in average crossover, intermediate crossover
CM_IS_PARAM_INT=( 1 1 1 0 1 1 1 0 );
#
numCmds=2; # number of commands to choose for crossover (algorithms for two or more cmds exist)
topN=5;
iterNum=420; # specify iteration num (directory num) to write scripts containing commands from current and previous gen 
outputNum=420; # specify file num where commands from current and previous gen will be written to allow parallel execution with other files
#
resultsPath="../optimRes";
cmdsDirInput="cmds"; # to look for these scripts: *_top*.sh
cmdsDirOutput="cmds1"; # to create these scripts: raw_*.sh
mkdir -p $cmdsDirOutput;
#
# choose *.sh file randomly with commands that MIGHT become "parents"
cmdsFilesInput=($(find "$cmdsDirInput" -maxdepth 1 -type f -name "*.sh" ! -name "*_top*" | sed 's/.*DS\([0-9]*\).*/\1 &/' | sort -n | cut -d ' ' -f 2-));
cmdsFileInput=${cmdsFilesInput[$((RANDOM % ${#cmdsFilesInput[@]}))]};
echo "###" $cmdsFileInput "###############################################################################################";
#
# potential "parent" cmds, aka commands that have been executed in previous generation
cmds=();
while IFS= read -r line; do
    cmds+=("${line}");
done < <( cat $cmdsFileInput );
#
# SELECTION #####################################################################################################################################
#
# # IF SELECTION MODE = ELITIST THEN
# chosenCmds=();
# while IFS= read -r line; do
#     chosenCmds+=("${line}");
# done < <( cat $cmdsFileInput | head -n +$topN | head -n +$numCmds );
#
# IF SELECTION MODE = ROULETTE THEN
# extract the bPS (bits per symbol) as array
dsFileInput=$resultsPath/$(basename $cmdsFileInput | sed "s/.sh/.tsv/");
bPSvalsStr=$(awk -F '[\t]' 'NR>2{print $4}' "$dsFileInput");
#
bPSvalsArr=(); # f(x)
while IFS= read -r line; do
    bPSvalsArr+=("$line")
done <<< "$bPSvalsStr"
echo "bPS vals, aka f(x) = ( ${bPSvalsArr[@]} )"
#
bPSvalsSum="${#bPSvalsArr[@]}"
echo "num of f(x) vals, aka |f(x)| = $bPSvalsSum"
#
# determine min and max bPS values (they're necessary because it is a minimization problem)
bPSmin=${bPSvalsArr[0]};
bPSmax=${bPSvalsArr[-1]};
echo "min f(x) = $bPSmin; max f(x) = $bPSmax";
#
# calculate sum of all bPS values
bPSsum=$(IFS="+"; echo "scale=6;${bPSvalsArr[*]}" | bc); # F
echo "sum of each f(x), aka F = $bPSsum";
#
# calculate probabilities of each bPS, p(x) and the cumulative sum of these probabilities, r(x)
bPSprobs=(); # p(x)
for bPSval in ${bPSvalsArr[@]}; do
    # bPSprob=$(bc <<< "scale=6; ($bPSval - $bPSmin)/($bPSmax-$bPSmin)"); # with normalization
    bPSprob=$(bc <<< "scale=6; ($bPSsum - $bPSval)/$bPSsum");
    bPSprobs+=( $bPSprob );
done; 
echo "each probability, aka p(x) = ( ${bPSprobs[@]} )";
#
# even though the p(x) values make some sense (values closer to minimum have bigger "slices"), their sum!=1,
# THUS each p(x_i) is updated by applying simple rule three
bPSprobsSum=$(IFS="+"; echo "scale=6;${bPSprobs[*]}" | bc); # sum(p(x))
echo "sum of probabilities is $bPSprobsSum != 1";
#
bPSprobs_new=(); # p'(x)
bPScumSumProbs=(); # r(x)
bPScumSumProb=0; # "current" r(x)
for bPSprob in ${bPSprobs[@]}; do 
    bPSprob_new=$(echo "scale=6; $bPSprob/$bPSprobsSum" | bc);
    bPScumSumProb=$(echo "$bPScumSumProb + $bPSprob_new" | bc);
    #
    bPSprobs_new+=( $bPSprob_new );
    bPScumSumProbs+=( $bPScumSumProb );
done;
#
# update bPSprobs array, aka p(x)
bPSprobs=();
for bPSprob_new in ${bPSprobs_new[@]}; do
    bPSprobs+=($bPSprob_new);
done
#
# unset vars that will not longer be used
unset bPSprob bPScumSumProb bPSprob_new bPSprobs_new;
#
echo "updated bPS probs, aka p(x) = ( ${bPSprobs[*]} )";
echo "bPS cumulative sum of their probs, aka r(x) = ( ${bPScumSumProbs[*]} )";
#
# check that the sum of probabilities is approximately 1
bPSprobsSum=$(IFS="+"; echo "scale=6; ${bPSprobs[*]}" | bc);
echo "updated sum of probabilities is $bPSprobsSum ~= 1";
#
last_bPScumSumProb=${bPScumSumProbs[-1]};
rouletteChoices=( $( seq 0 0.0001 $last_bPScumSumProb | sort -R | head -n $numCmds ) );
#
chosenCmds=();
chosenCmdsIdxs=(); # for debug purposes
for rndNum in ${rouletteChoices[@]}; do
    for bPScumSumProbIdx in ${!bPScumSumProbs[@]}; do 
        if [ $(echo "$rndNum <= ${bPScumSumProbs[$bPScumSumProbIdx]}"|bc) -eq 1 ]; then
            chosenCmdIdx=$bPScumSumProbIdx;
            chosenCmds+=( "${cmds[$chosenCmdIdx]}" )
            chosenCmdsIdxs+=( $chosenCmdIdx )
            break
        fi
    done
done; 
echo CMD INDEXES: ${chosenCmdsIdxs[@]}
#
command="${chosenCmds[0]}";
command2="${chosenCmds[1]}";
#
# original commands
# command="../bin/JARVIS3 -cm 2:500:1:0.9/4:5:0:0.0 -cm 5:1:1:0.9/2:5:1:0.8  -rm 20:13:0.9:6:0.7:1:0.06:2  -o ../../sequences/TME204.HiFi_HiC.haplotig2.1.seq.jc ../../sequences/TME204.HiFi_HiC.haplotig2.seq"
# command2="../bin/JARVIS3 -cm 2:100:1:0.9/0:5:1:0.8 -cm 2:5:1:0.9/2:1:0:0.2  -rm 200:13:0.9:4:0.7:1:0.06:2  -o ../../sequences/TME204.HiFi_HiC.haplotig2.2.seq.jc ../../sequences/TME204.HiFi_HiC.haplotig2.seq"
#
echo "raw commands randomly chosen";
echo ${command[@]}; 
echo ${command2[@]};
#
# DISASSEMBLE "PARENT" COMMANDS #####################################################################################################################################
#
# remove -o argument (if it exists)
command=$(echo "$command" | sed 's/\s*-o\s*[^ ]*//');
command2=$(echo "$command2" | sed 's/\s*-o\s*[^ ]*//');
#
printf "\nb4 crossing (without -o flag):\n"
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
# CROSSOVER #####################################################################################################################################
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
# IF CROSSOVER_TYPE = UNIFORM, THEN create uniform crossover mask
# for (( i=0; i < $NUM_PARAMS_PER_MODEL; i++)); 
#     do crossoverMask+=( $(( RANDOM % 2 )) ); 
# done;
#
# IF CROSSOVER_TYPE = X-POINT, THEN create x-point crossover "mask"
# choose cross points indexes
# maxNumCrosspoints=3;
# numCrosspoints=$((RANDOM % $maxNumCrosspoints + 1));
# crossPointIdxs=( $( seq 0 1 $((NUM_PARAMS_PER_MODEL-1)) | sort -R | head -n $numCrosspoints | sort ) );
# #
# # xpointCrossoverMask is used to create the actual crossoverMask, where 0 => bit equals previous bit and 1 => bit difers from previous one
# xpointCrossoverMask=(0 0 0 0 0 0 0 0);
# for crossPointIdx in ${crossPointIdxs[@]}; do
#     xpointCrossoverMask[$crossPointIdx]=1;
# done
# #
# crossoverMask=( $((RANDOM % 2)) );
# for toCutOrNotToCut in ${xpointCrossoverMask[@]}; do
#     if [ "$toCutOrNotToCut" -eq 0 ]; then # copy previous bit if we are not at a cut point
#         crossoverMask+=( ${crossoverMask[-1]} )
#     elif [ ${crossoverMask[-1]} -eq 1 ]; then # at a cut point, if previous bit is 1, then current bit is 0
#         crossoverMask+=( 0 );
#     elif [ ${crossoverMask[-1]} -eq 0 ]; then # at a cut point, if previous bit is 0, then current bit is 1
#         crossoverMask+=( 1 );
#     else 
#         echo "something strange happened when creating x-point crossover mask...";
#     fi;
# done;
# echo ${xpointCrossoverMask[@]}
# echo "$numCrosspoints point crossover mask (cut indexes: ${crossPointIdxs[@]}): ${crossoverMask[@]}"
# #
# # to make sure that crossoverMask has at least one elem equal to 1
# crossoverMasksum=$(IFS="+"; echo "scale=3;${crossoverMask[*]}" | bc);
# if [ $crossoverMasksum -eq 0 ]; then 
#     crossoverMask[$((RANDOM % ${#crossoverMask[@]}))]=1;
# fi
# #
# echo "crossover mask -------------------------------> " ${crossoverMask[@]};
# #
# for paramIdx in ${!crossoverMask[@]}; do
#     if [ ${crossoverMask[$paramIdx]} -eq 1 ]; then
#         # param ("gene") crossover itself
#         temp=${cm_params_arr[$paramIdx]};
#         cm_params_arr[$paramIdx]=${cm_params_arr2[$paramIdx]};
#         cm_params_arr2[$paramIdx]=$temp;
#     fi;
# done
#
# IF CROSSOVER_TYPE = AVERAGE CROSSOVER, THEN [no crossoverMask]
# cm mask has 6 integer nums (1) and 2 real nums (0)
# for paramIdx in ${!CM_IS_PARAM_INT[@]}; do
#     cmParam1=${cm_params_arr[$paramIdx]} # parent 1
#     cmParam2=${cm_params_arr2[$paramIdx]} # parent 2
#     #
#     if [ ${CM_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then # avg of two integer nums
#         avgParam=$(echo "scale=0;($cmParam1+$cmParam2)/2" | bc);
#     else # avg of two real nums
#         avgParam=$(echo "scale=3;($cmParam1+$cmParam2)/2" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
#     fi
#     #
#     cm_params_arr[$paramIdx]=$avgParam;
#     #
#     # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
#     cm_params_arr2[$paramIdx]=$avgParam; 
# done
#
# IF CROSSOVER_TYPE = DISCRETE CROSSOVER, THEN
# [r=random.choice({x, y}), if r==0, childParam=p1Param; elif r==1, childParam=p2Param]
# for paramIdx in $(seq 0 1 $((NUM_PARAMS_PER_MODEL-1)) ); do
#     cmParam1="${cm_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
#     cmParam2="${cm_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
#     # 
#     cmParamChoices=( "$cmParam1" "$cmParam2" ); # chose param with idx=$paramIdx from either parent1 or parent2
#     rndIdx=$((RANDOM % 2)); # random value taken from U(0,1)
#     chosenCmParam=${cmParamChoices[$rndIdx]};
#     #
#     # one child may become duplicate of another, but if that is the case, then it is removed later in the script
#     cm_params_arr[$paramIdx]=$chosenCmParam;
#     cm_params_arr2[$paramIdx]=${cm_params_arr[$paramIdx]};
# done;
#
# IF CROSSOVER_TYPE = FLAT CROSSOVER, THEN
# x is random val taken from U(param1,param2), if xi is integer then round result
for paramIdx in ${!CM_IS_PARAM_INT[@]}; do
    cmParam1="${cm_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
    cmParam2="${cm_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
    #
    childParam=$cmParam1;
    #
    if [ $(echo "$cmParam1 != $cmParam2" | bc -l) -eq 1 ]; then
        cmParam1and2=( $cmParam1 $cmParam2 );
        IFS=$'\n'; cmParam1and2sorted=($(sort -n <<<"${cmParam1and2[*]}")); unset IFS;
        #
        cmParamMin=${cmParam1and2sorted[0]};
        cmParamMax=${cmParam1and2sorted[-1]};
        cmParamsDiff=$(echo "scale=0; $cmParamMax-$cmParamMin"|bc);
        echo "$cmParamsDiff"
        #
        # random real number choosen from U(cmParamMin, cmParamMax)
        childParam=$( seq $cmParamMin 0.1 $cmParamMax | sort -R | head -n 1 );
        # 
        # round number with 0 decimals if param type is int
        if [ ${CM_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then
            childParam=$(echo "scale=0; $childParam/1" | bc);
        fi
    fi
    #
    # one child may become duplicate of another, but if that is the case, then it is removed later in the script
    cm_params_arr[paramIdx]=$childParam;
    cm_params_arr2[paramIdx]=${cm_params_arr[paramIdx]};
done
#
# IF CROSSOVER_TYPE = HEURISTIC/INTERMEDIATE CROSSOVER, THEN
# formula that produces ONE child = p1 + random * ratio_weight * (p2 - p1)
# 
# for paramIdx in ${!CM_IS_PARAM_INT[@]}; do
#     cmParam1="${cm_params_arr[$paramIdx]}"; # param with idx=$paramIdx from parent 1
#     cmParam2="${cm_params_arr2[$paramIdx]}"; # param with idx=$paramIdx from parent 2
#     #
#     randomNum="0.$((RANDOM%999))";
#     ratioWeight=1;
#     childParam=$(echo "scale=3; $cmParam1 + $randomNum * $ratioWeight * ($cmParam2 - $cmParam1)" | bc | sed '/\./ s/\.\{0,1\}0\{1,\}$//');
#     #
#     if [ ${CM_IS_PARAM_INT[$paramIdx]} -eq 1 ]; then # round value to int if params are int
#         childParam=$(echo "scale=0; $childParam/1" | bc);
#     fi
#     #
#     cm_params_arr[$paramIdx]=$childParam;
#     #
#     # this child may become a duplicate of other, but if that is the case, then it is removed later in the script
#     cm_params_arr2[$paramIdx]=$childParam;
# done
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
# MUTATION #####################################################################################################################################
#
chosenCmd=$(( RANDOM % $numCmds )); # choose command where mutation will occur
if [ $chosenCmd -eq 0 ]; then
    chosenCmIdx=$(( RANDOM % ${#cms_arr[@]} ));
    chosenCm="${cms_arr[$chosenCmIdx]}"; # choose CM where mutation will occur (str)
else 
    chosenCmIdx=$(( RANDOM % ${#cms_arr2[@]} ));
    chosenCm="${cms_arr2[$chosenCmIdx]}"; # choose CM where mutation will occur (str)
fi;
echo; echo "chosen cm from command$(($chosenCmd+1)) b4 mutation (str) ----> $chosenCm (index $chosenCmIdx)"
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
echo "mutation mask --------------------------------> " ${mutationMask[@]}
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
# ASSEMBLE "CHILDREN" COMMANDS #####################################################################################################################################
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
printf "\nafter crossing and possible mutation (without -o arg):\n"
echo $command
echo $command2
#
# add customized -o argument to avoid overwriting the same file during paralel computing
# inputFilename=$(echo "$command" | awk '{print $NF}');
# command=$(echo ${command//$inputFilename/} "-o ${inputFilename//.seq/.$outputNum.seq.jc}" "$inputFilename");
# #
# inputFilename2=$(echo "$command2" | awk '{print $NF}');
# command2=$(echo ${command2//$inputFilename2/} "-o ${inputFilename2//.seq/.$outputNum.seq.jc}" "$inputFilename2");
# #
# printf "\nafter crossing and possible mutation (with costumized -o arg):\n"
# echo $command;
# echo $command2;
#
# write "child" commands into cmds$N/$scriptDS.sh
basenameOutputFile=$(basename "$cmdsFileInput"| sed "s/_top${topN}//");
cmdsFileOutput=$cmdsDirOutput/$basenameOutputFile;
rm -fr $cmdsFileOutput; # rewrite file if it exists
echo "$command" >> $cmdsFileOutput;
echo "$command2" >> $cmdsFileOutput;
#
# remove duplicate lines
sort -o $cmdsFileOutput -u $cmdsFileOutput;
#
# allow execution of script where commands have just been written to
chmod +x $cmdsFileOutput;
