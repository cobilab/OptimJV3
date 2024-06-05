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
# === SELECTION FUNCTIONS ================================================================================================
#
function ELITIST_SELECTION() {
    echo "=========================== ELITIST SELECTION =====================================";
    chosenCmds=();
    while IFS= read -r line; do
        chosenCmds+=( "$line" );
    done < <( head -n +$numSelectedCmds $cmdsFileInput );
}
#
function ROULETTE_SELECTION() {
    echo "=========================== ROULETTE SELECTION =====================================";
    #
    # extract the bPS (bits per symbol) as array
    dsFileInput="../${ds}/$ga/g$gnum.tsv";
    echo "ds file input: $dsFileInput; gen num: $gnum";
    bPSvalsArr=( $(awk -F '[\t]' 'NR>2{print $4}' "$dsFileInput") );
    echo "bPS vals, aka f(x) = ( ${bPSvalsArr[@]} )"
    #
    bPSvalsNum="${#bPSvalsArr[@]}"
    echo "num of f(x) vals, aka |f(x)| = $bPSvalsNum"
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
    rouletteChoices=( $( seq 0 0.0001 $last_bPScumSumProb | sort -R --random-source=<(yes $((seed=seed+si))) | head -n $numSelectedCmds ) );
    #
    chosenCmds=();
    chosenCmdsIdxs=(); # for debug purposes
    for rndNum in ${rouletteChoices[@]}; do
        for bPScumSumProbIdx in ${!bPScumSumProbs[@]}; do 
            if [ $(echo "$rndNum <= ${bPScumSumProbs[$bPScumSumProbIdx]}"|bc) -eq 1 ]; then
                chosenCmdIdx=$bPScumSumProbIdx;
                chosenCmds+=( "$(awk -v idx=$chosenCmdIdx 'NR==idx' $cmdsFileInput)" );
                chosenCmdsIdxs+=( $chosenCmdIdx );
                break
            fi
        done
    done; 
    echo CMD INDEXES: ${chosenCmdsIdxs[@]};
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
# === CROSSOVER FUNCTIONS ================================================================================================
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
    --selection|--sel|-s) # elitist, roulette, tournament
        SELECTION_OP="$2";
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
    cmdsFilesInput+=( "../${ds}/$ga/adultCmds.txt" );
done
#
for cmdsFileInput in ${cmdsFilesInput[@]}; do
    #
    dsGAfolder=$(dirname $cmdsFileInput);
    echo $dsGAfolder ds ga folder
    nextGen=$((gnum+1));
    selCmdsFileOutput="$dsGAfolder/g${gnum}_selection.txt";
    #
    echo "========================================================";
    echo "ADULT CMDS FILE INPUT: $cmdsFileInput";
    echo "SEL CMDS FILE OUTPUT: $selCmdsFileOutput";
    #
    # adult cmds that have already been executed
    cmds=();
    while IFS= read -r line; do
        cmds+=("${line}");
    done < <( cat $cmdsFileInput );     
    #
    # === SELECTION ================================================================================================
    #
    if [ "$SELECTION_OP" = "elitist" ] || [ "$SELECTION_OP" = "e" ]; then
        ELITIST_SELECTION;
    elif [ "$SELECTION_OP" = "roulette" ] || [ "$SELECTION_OP" = "r" ]; then
        ROULETTE_SELECTION;
    elif [ "$SELECTION_OP" = "tournament" ] || [ "$SELECTION_OP" = "t" ]; then
        TOURNAMENT_SELECTION;
    fi
    #
    printf "%s \n" "${chosenCmds[@]}" > $selCmdsFileOutput;
    #
    numUniqueCmds=$(sort $selCmdsFileOutput | uniq -c | wc -l);
    #
    if [ $numUniqueCmds -eq $numSelectedCmds ]; then 
        echo "$numUniqueCmds unique selected commands";
    else
        selCmdsFileOutputTMP="${selCmdsFileOutput/.txt/TMP.txt}"
        echo "$numSelectedCmds selected commands, $numUniqueCmds of them are unique";
        echo "Duplicates of these commands will be removed:";
        sort $selCmdsFileOutput | uniq -c | awk '$1>1';
        sort $selCmdsFileOutput | uniq -c | awk '{$1=""; print}' > $selCmdsFileOutputTMP;
        rm -fr $selCmdsFileOutput;
        mv $selCmdsFileOutputTMP $selCmdsFileOutput;
    fi
done
