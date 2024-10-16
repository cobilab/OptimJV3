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
    # input file with values required for creating a roulette
    dsFileInput="$gaFolder/generations/g$gnum.tsv"
    echo "ds file input: $dsFileInput; gen num: $gnum"
    #
    roulette="$selFolder/roulette.tsv"
    initialRoulette="${roulette/roulette/initialRoulette}"
    echo "roulette file: $roulette; initial roulette: $initialRoulette"
    #
    # f size
    fSize=$(awk 'NR>2' $dsFileInput | sed -n '/[^[:space:]]/p' | wc -l)
    echo "|f(x)| = $fSize"
    #
    # sum of all f values, F
    F=$(awk 'NR==2{ if ($3 ~ /DOMINANCE/) {col=3} else {col=5} } NR>2{sum+=$col} END{print sum}' $dsFileInput)
    echo "sum f(x) = F = $F"
    #
    # initialize roulette with f(x), p(x), r(x) and cmd columns
    (   awk -F'\t' -v F=$F -v n=$fSize 'NR==2{ 
        if ($3 ~ /DOMINANCE/) {col=3} else {col=5} # column number
        print "f(x)\tp(x)\tr(x)\tcmds"
    } NR>2{
        validityVal=$2
        if (validityVal!=1) {
            f=$col # f(x), bps or domain values
            if (n!=1) { p=(1-f/F)/(n-1) } else { p=1 } # p(x)
            r+=p # r(x), cumulative sum of p(x)
            cmd=$NF
            print f"\t"p"\t"r"\t"cmd
        }
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
# similar to roulette, but instead of evaluating each individual by fitness,
# they are evaluated by their ranking.
# the best has rank 1, the second best rank 2, and so on.
function RANK_SELECTION() {
    echo "=========================== RANK SELECTION =====================================";
    #
    rank="$selFolder/rank.tsv"
    initialRank="${rank/rank/initialRank}"
    echo "rank file: $rank; initial rank: $initialRank"
    #
    # f size
    fSize=$(cat $cmdsFileInput | wc -l)
    echo "|f(x)| = $fSize"
    #
    # sum of all f values, F
    ls -la $cmdsFileInput
    F=$(awk '{sum+=++i}END{print sum}' $cmdsFileInput)
    echo "sum f(x) = F = $F"
    #
    # initialize rank with f(x), p(x), r(x) and cmd columns
    (   printf "f(x)\tp(x)\tr(x)\tcmds\n"
        awk -F'\t' -v F=$F -v n=$fSize '{
        f=++i # f(x), bps or domain values (rank)
        if (n!=1) { p=(1-f/F)/(n-1) } else { p=1 } # p(x)
        r+=p # r(x), cumulative sum of p(x)
        cmd=$NF
        print f"\t"p"\t"r"\t"cmd
    }' "$cmdsFileInput" ) > $rank
    cat $rank > $initialRank
    #
    for i in $(seq 1 $numSelectedCmds); do
        #
        # pick a random number between 0 and 1 to choose a command
        rmin=$(awk 'NR==2{print $3}' $rank)
        rmax=$(awk 'END{print $3}' $rank)
        rndNum=0.$((RANDOM%99999))$((RANDOM%9))
        #
        # find selected cmd
        chosenCmd="$(awk -F'\t' -v r=$rndNum 'NR>1{if (r<$3) {print $NF;exit}}' $rank)"
        chosenCmds+=( "$chosenCmd" )
        chosenRowNum=$(awk -F'\t' -v r=$rndNum 'NR>1{if (r<$3) {print NR;exit}}' $rank)
        #
        # remove selected cmd from rank to not choose it again
        ( awk -v nr=$chosenRowNum 'NR!=nr {print}' $rank ) > $rank.bak && mv $rank.bak $rank
        #
        # update f size
        fSize=$(awk 'NR>1' $rank | sed -n '/[^[:space:]]/p' | wc -l)
        echo "|f(x)| = $fSize"
        #
        # update sum of all f values, F
        F=$(awk 'NR>1{sum+=$1} END{print sum}' $rank)
        echo "sum f(x) = F = $F"
        #
        # update rank stats
        (   awk -F'\t' -v F=$F -v n=$fSize 'NR==1{
            print "f(x)\tp(x)\tr(x)\tcmds"
        } NR>1{
            f=++i # f(x)
            if (n!=1) { p=(1-f/F)/(n-1) } else { p=1 } # p(x)
            r+=p # r(x)
            cmd=$NF # command
            print f"\t"p"\t"r"\t"cmd
        }' $rank ) > $rank.bak && mv $rank.bak $rank
    done
}
#
function TOURNAMENT_SELECTION() {
    winner="";
    winnerIdxs=();
    for i in $(seq 1 $numSelectedCmds); do
        #
        # guarantees that the chosen indexes have not won a tournament yet
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
        [ $cmdIdx1 -lt $cmdIdx2 ] && winnerIdx=$cmdIdx1 || winnerIdx=$cmdIdx2;
        #
        winnerIdxs+=($winnerIdx);
        winner="[idx $winnerIdx] ${cmds[$winnerIdx]}";
        printf "$i  winner between [idx $cmdIdx1] and [idx $cmdIdx2]: $winner\n";
        winner="$(echo $winner | awk -F'] ' '{print $2}')";
        chosenCmds+=( "$winner" );
    done
}
#
# ===================================================================================================
#
configJson="../config.json"
#
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
sequencesPath="../../sequences";
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
#
SELECTION_OP="elitist";
selRate=0.3 # 30% of individuals are selected for crossover
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
    # elitist, roulette, rank, tournament
    --selection|--sel|-sl) 
        SELECTION_OP="$2";
        shift 2;
        ;;
    --num-sel-cmds|-ns)
        numSelectedCmds="$2";
        shift 2;
        ;;
    --selection-rate|-sr)
        selRate="$2";
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
    cmdsFilesInput+=( "../${ds}/$ga/eval/adultCmds.txt" );
done
#
for cmdsFileInput in ${cmdsFilesInput[@]}; do
    #
    # if numSelectedCmds variable does not exist, numSelectedCmds = popSize x selRate
    popSize=$(cat $cmdsFileInput | wc -l)
    [ -z "$numSelectedCmds" ] && numSelectedCmds=$(echo $popSize $selRate | awk '{print int($1*$2)}')
    #
    gaFolder=$(dirname $cmdsFileInput | cut -d'/' -f1-3);
    nextGen=$((gnum+1));
    GET_SEED
    #
    selFolder="$gaFolder/sel"
    mkdir -p $selFolder
    selCmdsFileOutput="$selFolder/selectedCmds.txt";
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
    if [ $numSelectedCmds -gt ${#cmds[@]} ]; then numSelectedCmds="${#cmds[@]}"; fi 
    #
    # === SELECTION ================================================================================================
    #
    if [ "$SELECTION_OP" = "elitist" ] || [ "$SELECTION_OP" = "e" ]; then
        ELITIST_SELECTION;
    elif [ "$SELECTION_OP" = "roulette" ] || [ "$SELECTION_OP" = "rws" ]; then
        ROULETTE_SELECTION;
    elif [ "$SELECTION_OP" = "rank" ] || [ "$SELECTION_OP" = "rnk" ]; then
        RANK_SELECTION;
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
    #
    # this should not happen
    else
        selCmdsFileOutputTMP="${selCmdsFileOutput/.txt/TMP.txt}"
        echo "$numSelectedCmds selected commands, $numUniqueCmds of them are unique";
        echo "Duplicates of these commands will be removed:";
        sort $selCmdsFileOutput | uniq -c | awk '$1>1';
        sort $selCmdsFileOutput | uniq -c | awk '{$1=""; print}' > $selCmdsFileOutputTMP;
        rm -fr $selCmdsFileOutput;
        mv $selCmdsFileOutputTMP $selCmdsFileOutput;
    fi
    #
    seed=$((seed+si)) && SAVE_SEED
done
