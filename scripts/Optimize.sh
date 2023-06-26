#!/bin/bash
#
# ./RunSeqs.sh [--size xs|s|m|l|xl]1> ../results/bench-results-raw.txt 2> ../results/sterr.txt
#
resultsPath="../results";
bin_path="../bin/";
#
csv_dsToSize="dsToSize.csv";
declare -A dsToSize;

sizes=("xs" "s" "m" "l" "xl"); # to be able to filter genomes to run by size 
ALL_GENS_IN_DIR=( $(ls -S | egrep ".seq$" | sed 's/\.seq$//' | tac) ) # ( "test" ) # manual alternative
GENOMES=() # gens that have the required size will be added here
#
# ==============================================================================
#
function LOAD_CSV_DSTOSIZE() {
  while IFS=, read -r ds bytes size; do
    # Skip the header line
    if [[ "$ds" != "ds" ]]; then
      dsToSize[$ds]=$size;
    fi
  done < $csv_dsToSize;
}
#
# ==============================================================================
#
# RUN_TEST "compressor_name" "original_file" "compressed_file" "decompressed_file" "c_command" "d_command" "$run"; run=$((run+1));
function RUN_TEST() {
  #
  NAME="$1";
  IN_FILE="$2";
  FILEC="$3";
  FILED="$4";
  C_COMMAND="$5";
  D_COMMAND="$6";
  nrun="$7";
  #
  stdErrC="stderrC_ds${ds_id}_$size.txt";
  stdErrD="stderrD_ds${ds_id}_$size.txt";
  #
  # some compressors need extra preprocessing
  if [[ $NAME == MFC* || $NAME == DMcompress* ]]; then 
    echo ">x" > $IN_FILE;
    cat ${IN_FILE%.orig} >> $IN_FILE;
    printf "\n" >> $IN_FILE;
  elif [[ $NAME == LZMA* || $NAME == BZIP2* ]]; then
    cp ${IN_FILE%.orig} $IN_FILE;
  fi
  #
  BYTES=`ls -la $IN_FILE | awk '{ print $5 }'`;
  #
  # https://man7.org/linux/man-pages/man1/time.1.html
  # %e: (Not in tcsh(1).)  Elapsed real time (in seconds).
  # %M: Maximum resident set size of the process during its lifetime, in Kbytes.
  /bin/time -f "TIME\t%e\tMEM\t%M" $C_COMMAND \
  |& grep "TIME" \
  |& tr '.' ',' \
  |& awk -v dividendo="$dividendo" '{ printf $2/dividendo"\t"$4/1024/1024"\n" }' 1> c_time_mem.txt 2> $stdErrC;
  if [ -e "$FILEC" ]; then
    BYTES_CF=`ls -la $FILEC | awk '{ print $5 }'`;
    BPS=$(echo "scale=3; $BYTES_CF*8 / $BYTES" | bc);
  else 
    BYTES_CF=-1;
    BPS=-1;
  fi
  #
  /bin/time -f "TIME\t%e\tMEM\t%M" $D_COMMAND \
  |& grep "TIME" \
  |& tr '.' ',' \
  |& awk -v dividendo="$dividendo" '{ printf $2/dividendo"\t"$4/1024/1024"\n" }' 1> d_time_mem.txt 2> $stdErrD;
  #
  # compare input file to decompressed file; they should have the same sequence
  diff <(tail -n +2 $IN_FILE | tr -d '\n') <(tail -n +2 $FILED | tr -d '\n') > cmp.txt;
  #
  C_TIME=`printf "%0.3f\n" $(cat c_time_mem.txt | awk '{ print $1 }')`;
  C_MEME=`printf "%0.3f\n" $(cat c_time_mem.txt | awk '{ print $2 }')`;
  D_TIME=`printf "%0.3f\n" $(cat d_time_mem.txt | awk '{ print $1 }')`;
  D_MEME=`printf "%0.3f\n" $(cat d_time_mem.txt | awk '{ print $2 }')`;
  VERIFY="0";
  CMP_SIZE=`ls -la cmp.txt | awk '{ print $5}'`
  if [[ "$CMP_SIZE" != "0" ]]; then CMP_SIZE="1"; fi
  #
  printf "$NAME\t$BYTES\t$BYTES_CF\t$BPS\t$C_TIME\t$C_MEME\t$D_TIME\t$D_MEME\t$CMP_SIZE\t$nrun\n";
  #
  if [ ! -s $stdErrC ]; then rm -fr $stdErrC; fi
  if [ ! -s $stdErrD ]; then rm -fr $stdErrD; fi
  #
  rm -fr $FILEC $FILED c_tmp_report.txt d_tmp_report.txt c_time_mem.txt d_time_mem.txt
  #
}
#
# === MAIN ===========================================================================
#
LOAD_CSV_DSTOSIZE;

mkdir -p $resultsPath naf_out mbgc_out paq8l_out;

# if one or more sizes are choosen, select all genomes with those sizes
for size in "${sizes[@]}"; do
  if [[ "$*" == *"--size $size"* || "$*" == *"-s $size"* ]]; then
    for gen in "${ALL_GENS_IN_DIR[@]}"; do
        if [[ "${dsToSize[$gen]}" == "$size" ]]; then
            GENOMES+=("$gen");
        fi
    done
  fi
done

# if one or more gens are choosen, add them to array if they aren't there yet
for gen in "${ALL_GENS_IN_DIR[@]}"; do
  if [[ "$*" == *"--genome $gen"* || "$*" == *"-g $gen"* ]]; then
    if ! echo "${GENOMES[@]}" | grep -q -w "$gen"; then
      GENOMES+=("$gen");
    fi
  fi
done

#
# if nothing is choosen, all genomes will be selected
if [ ${#GENOMES[@]} -eq 0 ]; then
  GENOMES=("${ALL_GENS_IN_DIR[@]}");
fi
#
# ------------------------------------------------------------------------------
#
for genome in "${GENOMES[@]}"; do
    #
    # before running the tests, determine size type of sequence to know: 
    # - the number of times each test should be executed (maybe); 
    # - whether c/d time should be in ms, s, m,...
    #
    ds_id=$(($(grep -n "$genome" dsToSize.csv | cut -d ":" -f 1)-1))
    size=${dsToSize[$genome]};
    # num_runs_to_repeat=1;
    dividendo=60; str_time="m"; # bigger files => slower tests => time measured in minutes
    if [ "$size" = "xs" ] || [ "$size" = "s" ]; then # smaller files => faster tests => time measured in seconds
      # num_runs_to_repeat=10;
      dividendo=1; str_time="s";
    fi
    #
    output_file_ds="$resultsPath/bench-results-raw-ds${ds_id}-${size}.txt";
    run=0;
    #
    # --- RUN GENOME TESTS ---------------------------------------------------------------------------
    #
    printf "DS$ds_id - $genome - $size \nPROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME ($str_time)\tC_MEM (GB)\tD_TIME ($str_time)\tD_MEM (GB)\tDIFF\tRUN\n";
    #

    # PARAMETERS COMMON TO CM AND RM
    NB_C_lst=( {1..14} ) # context model size
    NB_I_lst=( {0,1,2} ) # manages inverted repeats
    NB_G_lst=($(seq 0 0.1 0.9)) # gamma

    # CM PARAMETERS
    NB_D_lst=( {1..5000} ) # alpha=1/NB_D => parameter estimator
    NB_S_lst=( {1..20} )
    NB_R_lst=( {0,1} )
    NB_E_lst=( {1..5000} )
    NB_A_lst=($(seq 0 0.1 0.9))

    # RM PARAMETERS
    NB_R_lst=( {1..10000} )
    NB_B_lst=($(seq 0 0.1 0.9))
    NB_L_lst=({1..10000}) # has dependency with NB_B
    NB_W=($(seq 0 0.1 0.9)) # initial weight for repeat classes
    NB_Y=({1..50}) # max cache size

    num_tests=100;

    for i in {1..$num_tests}; do
      min_cms=1;
      max_cms=5;

      min_rms=1;
      max_rms=1;

      CM="";
      for i in {1..$((RANDOM % $max_cms + $min_cms))}; do

        # randomly chosen cm parameter values
        NB_C=${NB_C_lst[$((RANDOM % ${#NB_C_lst[@]}))]};
        NB_D=${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}; 
        NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]}; 
        NB_G=${NB_G_lst[$((RANDOM % ${#NB_G_lst[@]}))]};
        NB_S=${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]};
        NB_R=${NB_R_lst[$((RANDOM % ${#NB_R_lst[@]}))]};
        NB_E=${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]};
        NB_A=${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]};

        CM+="-cm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_R}:${NB_E}:${NB_A}";
      done

      # randomly chosen rm parameter values
      NB_C=${NB_C_lst[$((RANDOM % ${#NB_C_lst[@]}))]};
      NB_D=${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}; 
      NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]}; 
      NB_G=${NB_G_lst[$((RANDOM % ${#NB_G_lst[@]}))]};
      NB_S=${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]};
      NB_R=${NB_R_lst[$((RANDOM % ${#NB_R_lst[@]}))]};
      NB_E=${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]};
      NB_A=${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]};

      RM="-rm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_R}:${NB_E}:${NB_A}";

      RUN_TEST "JARVIS3_BIN" "$genome.seq" "$genome.seq.jc" "$genome.seq.jc.jd" "${bin_path}JARVIS3 $CM $RM $genome.seq" "${bin_path}JARVIS3 -d $genome.seq.jc" "$run"; run=$((run+1));

    done
done
# 
