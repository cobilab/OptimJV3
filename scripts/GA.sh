#!/bin/bash
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
  echo " --view-datasets|--view-ds|-v..View sequence names, size";
  echo "           of each in bytes, MB, and BG, and their group";
  echo "--sequence|--seq|-s..........Select sequence by its name";
  echo "--sequence-group|--seq-grp|-sg.Select group of sequences";
  echo "                                           by their size";
  echo "--dataset|-ds......Select sequence by its dataset number";
  echo "--dataset-range|--dsrange|--drange|-dr............Select";
  echo "                   sequences by range of dataset numbers";
  echo "--nthreads|-t...........num of threads to run JARVIS3 in"; 
  echo "                                                parallel";
  echo "--seed|-sd..............Pseudo-random seed. Value: $seed";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
function CHECK_DS_INPUT () {
    FILE1=$1
    FILE2=$2
    if [ ! -f "$FILE1" ] && [ ! -f "$FILE2" ]; then
        echo -e "\e[31mERROR: one of these files or both were not found: $FILE1 and $FILE2"
        echo -e "Run Setup.sh or GetDSinfo.sh to fix issue\e[0m";
        exit 1;
    fi
}
#
### DEFAULT VALUES ###############################################################################################
#
INIT_GEN=1;
FIRST_GEN=1;
LAST_GEN=100;
POPULATION_SIZE=100;
#
ds_range="1:1";
nthreads=10;
seed=1;
si=10; # to increment seed
#
lr=0.03; # learning rate
#
ds_sizesBase2="../../DS_sizesBase2.tsv"
ds_sizesBase10="../../DS_sizesBase10.tsv"
CHECK_DS_INPUT "$ds_sizesBase2" "$ds_sizesBase10"
#
ga="ga";
#
logPath="../logs";
rm -fr $logPath;
mkdir -p $logPath;
#
### PARSING ###############################################################################################
#
allArgs="$@";
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
    --first-generation|--first-gen|-fg)
        FIRST_GEN="$2";
        shift 2;
        ;;
    --last-generation|--last-gen|-lg)
        LAST_GEN="$2";
        shift 2;
        ;;
    --genetic-algorithm|--algorithm|--ga|-ga|-a)
        ga="$2";
        flags+="-ga $ga ";
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
        ds="$2";
        SEQUENCES+=( "$(awk '/DS'$ds'[[:space:]]/{print $2}' "$ds_sizesBase2")" );
        shift 2;
        ;;
    --dataset-range|--dsrange|--drange|-dr)
        dsrange=( $(echo "$2" | sed 's/[:/]/ /g') );
        sorted_dsrange=( $(printf "%s\n" ${dsrange[@]} | sort -n ) );
        dsmin="${sorted_dsrange[0]}";
        dsmax="${sorted_dsrange[1]}";
        SEQUENCES+=( $(awk -v m=$dsmin -v M=$dsmax 'NR>=1+m && NR <=1+M {print $2}' "$ds_sizesBase2") );
        shift 2;
        ;;
    --population-size|--population|--psize|-ps|-p)
        POPULATION_SIZE="$2";
        initFlags+="-ps $POPULATION_SIZE ";
        evalFlags+="-ps $POPULATION_SIZE ";
        shift 2;
        ;;
    --seed|-sd)
        seed="$2";
        RANDOM=$seed;
        initFlags+="-sd $seed ";
        scmFlags+="-sd $seed ";
        shift 2;
        ;;
    --seed-increment|-si)
        si="$2";
        initFlags+="-si $si ";
        scmFlags+="-si $si ";
        shift 2;
        ;;
    #
    # INIT
    #
    --learning-rate|-lr) 
        # 0 value turns the NN off
        lr="$2";
        initFlags+="-lr $lr ";
        shift 2;
        ;; 
    --hidden-size|-hs) 
        # hidden size of the NN
        hs="$2";
        initFlags+="-hs $hs ";
        shift 2;
        ;; 
    #
    # RUN
    #
    --nthreads|-t)
        nthreads="$2";
        runFlags+="-t $nthreads ";
        shift 2;
        ;;
    #
    # EVALUATION
    #
    --moga-weightned-metric|--moga-wm|--moga)
        evalFlags+="--moga ";
        shift;
        ;;
    --moga-weightned-sum|--moga-ws)
        evalFlags+="--moga-ws ";
        shift;
        ;;
    --p-expoent|--p-exp)
        pExp="$2";
        evalFlags+="--p-exp $pExp ";
        shift 2;
        ;;
    --weight-bps|--w-bps|-w1)
        w_bPS="$2";
        evalFlags+="-w1 $w_bPS ";
        shift 2;
        ;;
    --weight-ctime|--w-ctime|-w2)
        w_CTIME="$2";
        evalFlags+="-w2 $w_CTIME ";
        shift 2;
        ;;
    #
    # SELECTION
    #
    --num-sel-cmds|-ns)
        ns="$2";
        scmFlags+="-ns $ns ";
        shift 2;
        ;;
    --selection|--sel) 
        # elitist, roulette
        SELECTION_OP="$2";
        scmFlags+="--sel $SELECTION_OP ";
        shift 2;
        ;;
    #
    # CROSSOVER
    #
    --crossover-rate|--xover-rate|--xrate|-xr|-cr)
        CROSSOVER_RATE=$(echo "scale=3; $2" | bc);
        scmFlags+="-cr $CROSSOVER_RATE ";
        shift 2;
        ;;
    --crossover|--xover|-x|-c) 
        # xpoint, uniform
        CROSSOVER_OP="$2";
        scmFlags+="-c $CROSSOVER_OP ";
        shift 2;
        ;;
    #
    # MUTATION
    #
    --mutation-rate|--mrate|-mr)
        MUTATION_RATE=$(echo "scale=3; $2" | bc);
        scmFlags+="-mr $MUTATION_RATE ";
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
    ;;
    esac
done
#
if [ ${#SEQUENCES[@]} -ne 0 ]; then 
    echo "Sequences to run: "
    printf "%s \n" "${SEQUENCES[@]}"
else 
    echo -e "\e[31mERROR: The program does not know which sequences to run"
    echo -e "run ./Setup.sh if required, then rerun this script with -v to view all datasets, or -h for help \e[0m";
    exit 1;
fi
#
### GA ########################################################################################################
#
for sequence in ${SEQUENCES[@]}; do
    #
    dsx=$(awk '/'$sequence'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    dsFolder="../$dsx";
    mkdir -p $dsFolder;
    gaFolder="$dsFolder/$ga";
    if [ -d $gaFolder ]; then mv $gaFolder ${gaFolder}_bkp; fi
    logFolder="$gaFolder/logs";
    mkdir -p $logFolder;
    #
    logFile="$logFolder/${dsx}_$ga.log"
    errFile="$logFolder/${dsx}_$ga.err"
    echo "log file: $logFile"
    echo "error file: $errFile"
    #
    initLogFolder="$logFolder/init"
    runLogFolder="$logFolder/run"
    evalLogFolder="$logFolder/eval"
    scmLogFolder="$logFolder/scm"
    mkdir -p $initLogFolder $runLogFolder $evalLogFolder $scmLogFolder
    #
    echo "./MainGA.sh $allArgs" > "$gaFolder/ga.sh";
    #
    ( echo "./MainGA.sh $allArgs"
    #
    if [ $FIRST_GEN -eq $INIT_GEN ]; then 
        initLog="$initLogFolder/init.log"
        initErr="$initLogFolder/init.err"
        echo "1. INITIALIZATION - log file: $initLog ; err file: $initErr";
        bash -x ./Initialization.sh -s $sequence $flags $initFlags 1> $initLog 2> $initErr; 
    fi
    #
    for gen in $(seq $FIRST_GEN $LAST_GEN); do
        echo "=== GENERATION $gen ===";
        #
        runLog="$runLogFolder/run$gen.log"
        runErr="$runLogFolder/run$gen.err"
        echo "2. RUN - log file: $runLog ; err file: $runErr";
        bash -x ./Run.sh -s $sequence -g $gen $flags $runFlags 1> $runLog 2> $runErr;
        #
        evalLog="$evalLogFolder/eval$gen.log"
        evalErr="$evalLogFolder/eval$gen.err"
        echo "3. EVALUATION - log file: $evalLog ; err file: $evalErr";
        bash -x ./Evaluation.sh -s $sequence -g $gen $flags $evalFlags 1> $evalLog 2> $evalErr;
        #
        scmLog="$scmLogFolder/scm$gen.log"
        scmErr="$scmLogFolder/scm$gen.err"
        echo "4. SELECTION, 5. CROSSOVER, 6. MUTATION - log file: $scmLog ; err file: $scmErr";
        bash -x ./SelCrossMut.sh -s $sequence -g $gen $flags $scmFlags 1> $scmLog 2> $scmErr;
    done ) 1> $logFile 2> $errFile &
    #
    echo "$dsx, $ga is running in the background..."
    wait # to run one GA at a time
    echo "$dsx, $ga program is complete"
done