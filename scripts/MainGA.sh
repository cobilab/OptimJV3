#!/bin/bash
#
### DEFAULT VALUES ###############################################################################################
#
FIRST_GEN=1;
LAST_GEN=100;
POPULATION=100;
#
ds_range="1:1";
nthreads=10;
seed=1;
si=10; # to increment seed
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
logPath="../logs";
errPath="../errors";
mkdir -p $logPath $errPath;
#
evalExtraFlags="";
scmExtraFlags="";
#
model="model";
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
    --model-folder|--model|-m)
        model="$2";
        shift 2; 
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
    --selection|--sel) # elitist, roulette
        SELECTION_OP="$2";
        scmExtraFlags+="--sel $SELECTION_OP ";
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
    --moga-weightned-metric|--moga-wm|--moga)
        evalExtraFlags+="--moga ";
        shift;
        ;;
    --moga-weightned-sum|--moga-ws)
        evalExtraFlags+="--moga-ws ";
        shift;
        ;;
    --p-expoent|--p-exp)
        pExp="$2";
        evalExtraFlags+="--p-exp $pExp ";
        shift 2;
        ;;
    --weight-bps|--w-bps|-w1)
        w_bPS="$2";
        evalExtraFlags+="-w1 $w_bPS ";
        shift 2;
        ;;
    --weight-ctime|--w-ctime|-w2)
        w_CTIME="$2";
        evalExtraFlags+="-w2 $w_CTIME ";
        shift 2;
        ;;
    --nthreads|-t)
        nthreads="$2";
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
if [ $gen -eq 1 ]; then 
    echo "1. INITIALIZATION - input: random ---> output: cmds1";
    ./Initialization.sh -m $model -p $POPULATION -dr "$ds_range" -sd $((seed=seed+si)) 1> $initLogPath/init.log 2> $initErrPath/init.err; 
fi
#
for gen in $(seq $FIRST_GEN $LAST_GEN); do 
    echo "2. RUN - input: cmds$gen ----> output: res$gen";
    ./Run.sh -m $model -g $gen -dr "$ds_range" -t $nthreads 1> $runLogPath/run$gen.log 2> $runErrPath/run$gen.err;
    #
    echo "3. EVALUATION - input: res from current and previous generations ----> output: res$gen";
    ./Evaluation.sh $evalExtraFlags -m $model -g $gen -dr "$ds_range" -p $POPULATION 1> $evalLogPath/eval$gen.log 2> $evalErrPath/eval$gen.err;
    #
    nextGen=$((gen+1));
    echo "4. SELECTION, 5. CROSSOVER, 6. MUTATION - input: res$gen ----> output: cmds$nextGen";
    ./SelCrossMut.sh $scmExtraFlags -m $model -g $gen -dr "$ds_range" -ns 30 -cr 1 -sd $((seed=seed+si)) -si $si 1> $scmLogPath/scm$gen.log 2> $scmErrPath/scm$gen.err;
    #
    cat $scmLogPath/scm$gen.log $runLogPath/run$gen.log $evalLogPath/eval$gen.log >> $logPath/cga.log;
    cat $scmErrPath/scm$gen.err $runErrPath/run$gen.err $evalErrPath/eval$gen.err >> $errPath/cga.err;
done
