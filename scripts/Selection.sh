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
    dsFileInput="$gaFolder/g$gnum.tsv"
    echo "ds file input: $dsFileInput; gen num: $gnum"
    #
    roulette="$scmFolder/roulette.txt"
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
        p=(1-$col/F)/(n-1) # p(x), https://stackoverflow.com/questions/8760473/roulette-wheel-selection-for-function-minimization
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
            p=(1-f/F)/(n-1) # p(x)
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
    --num-sel-cmds|-ns)
        numSelectedCmds="$2";
        shift 2;
        ;;
    --selection|--sel|-sl) # elitist, roulette, tournament
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
    gaFolder=$(dirname $cmdsFileInput);
    echo $gaFolder ds ga folder
    nextGen=$((gnum+1));
    #
    scmFolder="$gaFolder/scm"
    mkdir -p $scmFolder
    selCmdsFileOutput="$scmFolder/selectedCmds.txt";
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
