#!/bin/bash
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
  echo "--seed|-sd............................Pseudo-random seed";
  echo "                                                        ";
  echo "example 1: ./Main.sh -s human                           ";
  echo "example 2: ./Main.sh -s cassava -s human                ";
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
# ###############################################################################################
#
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],' )"
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],' )"
CHECK_DS_INPUT "$ds_sizesBase2" "$ds_sizesBase10"
#
min_gen=1
gen_range=100
max_gen=100
#
if [ $(w | wc -l) -gt 3 ]; then # if there is more than one user registered in the system
  nthreads=$(( $(nproc --all)/3 )); 
else
  nthreads=$(( $(nproc --all)-2 )); 
fi
#
# run experiment where each crossover and mutation script is tested.
# these scripts are tested in smaller population (20), fewer generations (100), and within a smaller search space,
# to provide greater challenge to its population diversity and premature convergence
testCrossMutScripts=false
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
        FIX_SEQUENCE_NAME "$sequence";
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
    --first-generation|--first-gen|-fg)
        min_gen="$2";
        shift 2;
        ;;
    --range-generation|--range-gen|-rg)
        gen_range="$2"
        shift 2
        ;;
    --last-generation|--last-gen|-lg)
        max_gen="$2";
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
    --nthreads|-t)
        nthreads="$2";
        runFlags+="-t $nthreads ";
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
    ;;
    esac
done
#
### GA ########################################################################################################
#
for fg in $(seq $min_gen $gen_range $max_gen); do
    #
    lg=$((fg+gen_range-1))
    if [ $lg -gt $max_gen ]; then lg=$max_gen; fi
    #
    # default minimum of rms=1
    for sequence in ${SEQUENCES[@]}; do
        echo $sequence $fg $lg
        #
        # canonical GA (run for 500 generations)
        # bash -x ./GA.sh -s "$sequence" -ga "e0_ga2_lr0_cmga" -lr 0 -fg $fg -lg $lg -t $nthreads # lr = 0
        #
        # === LR = 0 ====================================================
        #
        # change initialization technique
        bash -x ./GA.sh -s "$sequence" -ga "e1_ga1_lr0_hei" -lr 0 -hei -fg $fg -lg $lg -t $nthreads # heuristic initialization
        # bash -x ./GA.sh -s "$sequence" -ga "e1_ga2_lr0_hyi10" -lr 0 -hyi -hhp 0.1 -fg $fg -lg $lg -t $nthreads # hybrid initialization (10% heuristic, 90% random)
        # bash -x ./GA.sh -s "$sequence" -ga "e1_ga3_lr0_hyi25" -lr 0 -hyi -hhp 0.25 -fg $fg -lg $lg -t $nthreads # hybrid initialization (25% heuristic)
        # bash -x ./GA.sh -s "$sequence" -ga "e1_ga4_lr0_hyi50" -lr 0 -hyi -fg $fg -lg $lg -t $nthreads # hybrid initialization (50% heuristic)
        # #
        # # change population size
        # bash -x ./GA.sh -s "$sequence" -ga "e2_ga1_lr0_ps20" -lr 0 -ps 20 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "e2_ga2_lr0_ps50" -lr 0 -ps 50 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "e2_ga3_lr0_ps80" -lr 0 -ps 80 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "e2_ga4_lr0_ps150" -lr 0 -ps 150 -fg $fg -lg $lg -t $nthreads
        #
        # multi-objective GAs (weight metric)
        bash -x ./GA.sh -s "$sequence" -ga "e3_ga1_lr0_mogawm_wBPS10" -lr 0 --moga -wBPS 0.1 -pe 2 -fg $fg -lg $lg -t $nthreads
        bash -x ./GA.sh -s "$sequence" -ga "e3_ga2_lr0_mogawm_wBPS25" -lr 0 --moga -wBPS 0.25 -pe 2 -fg $fg -lg $lg -t $nthreads
        bash -x ./GA.sh -s "$sequence" -ga "e3_ga3_lr0_mogawm_wBPS50" -lr 0 --moga -wBPS 0.5 -pe 2 -fg $fg -lg $lg -t $nthreads
        bash -x ./GA.sh -s "$sequence" -ga "e3_ga4_lr0_mogawm_wBPS75" -lr 0 --moga -wBPS 0.75 -pe 2 -fg $fg -lg $lg -t $nthreads
        bash -x ./GA.sh -s "$sequence" -ga "e3_ga5_lr0_mogawm_wBPS90" -lr 0 --moga -wBPS 0.9 -pe 2 -fg $fg -lg $lg -t $nthreads
        #
        # # change selection rate
        bash -x ./GA.sh -s "$sequence" -ga "e4_ga1_lr0_selT" -lr 0 --sel "t" -fg $fg -lg $lg -t $nthreads # tournament
        bash -x ./GA.sh -s "$sequence" -ga "e4_ga2_lr0_selRWS" -lr 0 --sel "rws" -fg $fg -lg $lg -t $nthreads # roulette wheel selection
    done
done
