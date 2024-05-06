#!/bin/bash
#
### DEFAULT VALUES ###############################################################################################
#
FIRST_GEN=0;
LAST_GEN=100;
POPULATION=100;
#
ds_range="1:1";
nthreads=10;
seed=1;
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
logPath="../logs";
errPath="../errors";
mkdir -p $logPath $errPath;
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
  echo " --view-datasets|--view-ds|-v....View sequence names, the size"; 
  echo "                 of each in bytes, MB, and BG, and their group";
  echo "--sequence|--seq|-s..........Select sequence by its name";
  echo "--sequence-group|--seq-grp|-sg.Select group of sequences";
  echo "                                           by their size";
  echo "--dataset|-ds......Select sequence by its dataset number";
  echo "--dataset-range|--dsrange|--drange|-dr............Select";
  echo "                   sequences by range of dataset numbers";
  echo "--seed|-sd..............Pseudo-random seed. Value: $seed";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
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
    --sequence|--seq|-s)
        sequence="$2";
        shift 2; 
        ;;
    --sequence-group|--sequence-grp|--seq-group|--seq-grp|-sg)
        size="$2";
        shift 2; 
        ;;
    --dataset|-ds)
        ds="$2";
        shift 2;
        ;;
    --dataset-range|--dsrange|--drange|-dr)
        ds_range="$2";
        shift 2;
        ;;
    --num-sel-cmds|-ns)
        topN="$2";
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
    --selection|--sel|-s) # elitist, roulette
        SELECTION_OP="$2";
        shift 2;
        ;;
    --crossover|--xover|-x) # xpoint, uniform
        CROSSOVER_OP="$2";
        shift 2;
        ;;
    --population|--pop|-p)
        POPULATION="$2";
        shift 2;
        ;;
    --first-generation|--first-gen|-fg)
        FIRST_GEN="$2";
        shift 2;
        ;;
    --last-generation|--last-gen|-lg)
        LAST_GEN="$2";
        shift 2;
        ;;
    --seed|-sd)
        seed="$2";
        RANDOM=$seed;
        shift 2;
        ;;
    *) 
        # ignore any other arguments
        shift;
    ;;
    esac
done
#
initLogPath="$logPath/init${ds_range/:/_}";
runLogPath="$logPath/run${ds_range/:/_}";
evalLogPath="$logPath/eval${ds_range/:/_}";
scmLogPath="$logPath/scm${ds_range/:/_}";
mkdir -p $initLogPath $runLogPath $evalLogPath $scmLogPath;
#
initErrPath="$errPath/init${ds_range/:/_}";
runErrPath="$errPath/run${ds_range/:/_}";
evalErrPath="$errPath/eval${ds_range/:/_}";
scmErrPath="$errPath/scm${ds_range/:/_}";
mkdir -p $initErrPath $runErrPath $evalErrPath $scmErrPath;
#
### MAIN GA ########################################################################################################
#
gen=$FIRST_GEN;
#
if [ $gen -eq 0 ]; then 
    echo "1. INITIALIZATION";
    ./Initialization.sh -p $POPULATION -dr "$ds_range" -sd $seed 1> $initLogPath/init.log 2> $initErrPath/init.err; # input: random ---> output: 50 cmds are written into cmds0
    seed=$((seed+10));
    #
    echo "2. RUN - input: cmds0 ----> output: rawRes0";
    ./Run.sh -g 0 -dr "$ds_range" -t $nthreads 1> $runLogPath/run0.log 2> $runErrPath/run0.err;
    #
    echo "3. EVALUATION - input: rawRes0 ----> output: res0";
    ./Evaluation.sh -g 0 -dr "$ds_range" -p $POPULATION 1> $evalLogPath/eval0.log 2> $evalErrPath/eval0.err;
    #
    cat $initLogPath/init.log $runLogPath/run0.log $evalLogPath/eval0.log > $logPath/cga.log;
    cat $initErrPath/init.err $runErrPath/run0.err $evalErrPath/eval0.err > $errPath/cga.err;
fi
#
for gen in $(seq $FIRST_GEN $((LAST_GEN-1))); do 
    nextGen=$(($gen+1));
    #
    echo "4. SELECTION, 5. CROSSOVER, 6.MUTATION - input: res$gen ----> output: cmds$nextGen";
    ./SelCrossMut.sh -g $gen -dr "$ds_range" -ns 30 -cr 1 -sd $seed 1> $scmLogPath/scm$gen.log 2> $scmErrPath/scm$gen.err;
    seed=$((seed+10));
    #
    echo "2. RUN - input: cmds$nextGen ----> output: res$nextGen";
    ./Run.sh -g $nextGen -dr "$ds_range" -t $nthreads 1> $runLogPath/run$nextGen.log 2> $runErrPath/run$nextGen.err;
    #
    echo "3. EVALUATION - input: res$gen + res$nextGen ----> output: res$nextGen";
    ./Evaluation.sh -g $nextGen -dr "$ds_range" -p $POPULATION 1> $evalLogPath/eval$nextGen.log 2> $evalErrPath/eval$nextGen.err;
    #
    cat $scmLogPath/scm$gen.log $runLogPath/run$gen.log $evalLogPath/eval$gen.log >> $logPath/cga.log;
    cat $scmErrPath/scm$gen.err $runErrPath/run$gen.err $evalErrPath/eval$gen.err >> $errPath/cga.err;
done
