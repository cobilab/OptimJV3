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
ds_sizesBase2="../../DS_sizesBase2.tsv"
ds_sizesBase10="../../DS_sizesBase10.tsv"
CHECK_DS_INPUT "$ds_sizesBase2" "$ds_sizesBase10"
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
min_gen=1
gen_range=20
max_gen=20
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
        # CGA (canonical GA)
        bash -x ./GA.sh -s "$sequence" -ga "ga01" -fg $fg -lg $lg -t $nthreads
        # 
        # KBI (knowledge-based initialization)
        # bash -x ./GA.sh -s "$sequence" -ga "ga02_kbi" -kbi -fg $fg -lg $lg -t $nthreads
        #
        # GAs with population size = 6 (num sel cmds=30, so all cmds are selected)
        # bash -x ./GA.sh -s "$sequence" -ga "ga03_p6" -ps 6 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga04_p6_selT" -ps 6 -sl "t" -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga05_p6_selR" -ps 6 --sel "r" -fg $fg -lg $lg -t $nthreads
        #
        # GAs that vary in population size                       
        # bash -x ./GA.sh -s "$sequence" -ga "ga06_p10_ns4" -ps 10 -ns 4 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga07_p20_ns6" -ps 20 -ns 6 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga08_p50_ns16" -ps 50 -ns 16 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga09_p80_ns24" -ps 80 -ns 24 -fg $fg -lg $lg -t $nthreads
        # #
        # # GAs that vary in population size (learning rate=0)
        # bash -x ./GA.sh -s "$sequence" -ga "ga10_p10_ns4_cr1" -ps 10 -ns 4 -lr 0 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga11_p20_ns6_cr1" -ps 20 -ns 6 -lr 0 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga12_p50_ns16_cr1" -ps 50 -ns 16 -lr 0 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga13_p80_ns24_cr1" -ps 80 -ns 24 -lr 0 -fg $fg -lg $lg -t $nthreads
        # #
        # # GAs that vary in population size (crossover rate=1)
        # bash -x ./GA.sh -s "$sequence" -ga "ga14_p10_ns4_cr1" -ps 10 -ns 4 -cr 1 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga15_p20_ns6_cr1" -ps 20 -ns 6 -cr 1 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga16_p50_ns16_cr1" -ps 50 -ns 16 -cr 1 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga17_p80_ns24_cr1" -ps 80 -ns 24 -cr 1 -fg $fg -lg $lg -t $nthreads
        # #
        # # MOGAs (multiple-objective GAs)
        # bash -x ./GA.sh -s "$sequence" -ga "ga18_mogawm_wBPS10" --moga -wBPS 0.1 -pe 2 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga19_mogawm_wBPS25" --moga -wBPS 0.25 -pe 2 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga20_mogawm_wBPS50" --moga -wBPS 0.5 -pe 2 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga21_mogawm_wBPS75" --moga -wBPS 0.75 -pe 2 -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga22_mogawm_wBPS90" --moga -wBPS 0.9 -pe 2 -fg $fg -lg $lg -t $nthreads
        # #
        # # tournament selection and RWS (roulette wheel selection)
        # bash -x ./GA.sh -s "$sequence" -ga "ga23_selT" --sel "t" -fg $fg -lg $lg -t $nthreads
        # bash -x ./GA.sh -s "$sequence" -ga "ga24_selR" --sel "r" -fg $fg -lg $lg -t $nthreads
        #
        # todo: crossovers
        # example: uniform crossover
        #
        # todo: mutations
        # example: knowledge-based mutation
    done
done
    