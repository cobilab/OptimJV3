#!/bin/bash
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
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
flags="";
initFlags="";
runFlags="";
evalFlags="";
scmFlags="";
#
ga="ga";
#
logPath="../logs";
rm -fr $logPath;
mkdir -p $logPath;
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
        flags+="-s $sequence ";
        shift 2;
        ;;
    --sequence-group|--sequence-grp|--seq-group|--seq-grp|-sg)
        size="$2";
        flags+="-sg $size ";
        shift 2; 
        ;;
    --dataset|-ds)
        ds="$2";
        flags+="-ds $ds ";
        shift 2;
        ;;
    --dataset-range|--dsrange|--drange|-dr)
        ds_range="$2";
        flags+="-drange $ds_range ";
        shift 2;
        ;;
    --population-size|--population|--psize|-ps)
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
        # ignore any other arguments
        shift;
    ;;
    esac
done
#
### MAIN GA ########################################################################################################
#
gen=$FIRST_GEN;
#
if [ $gen -eq $INIT_GEN ]; then 
    echo "1. INITIALIZATION";
    echo "./Initialization.sh $flags $initFlags"
    bash -x ./Initialization.sh $flags $initFlags 1> $logPath/init.log 2> $logPath/init.err; 
fi
#
for gen in $(seq $FIRST_GEN $LAST_GEN); do
    echo "=== GENERATION $gen ===";
    #
    echo "2. RUN";
    bash -x ./Run.sh -g $gen $flags $runFlags 1> $logPath/run$gen.log 2> $logPath/run$gen.err;
    #
    echo "3. EVALUATION";
    bash -x ./Evaluation.sh -g $gen $flags $evalFlags 1> $logPath/eval$gen.log 2> $logPath/eval$gen.err;
    #
    nextGen=$((gen+1));
    echo "4. SELECTION, 5. CROSSOVER, 6. MUTATION";
    bash -x ./SelCrossMut.sh -g $gen $flags $scmFlags 1> $logPath/scm$gen.log 2> $logPath/scm$gen.err;
done
