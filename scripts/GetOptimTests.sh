#!/bin/bash
#
# ./RunSeqs.sh [--size xs|s|m|l|xl]1> ../results/bench-results-raw.txt 2> ../results/sterr.txt
#
resultsPath="../optimRes";
errPath="$resultsPath/err";
binPath="../bin/";
#
csv_dsToSize="dsToSize.csv";
declare -A dsToSize;

sizes=("xs" "s" "m" "l" "xl"); # to be able to filter SEQUENCES_NAMES to run by size 

sequencesPath="$HOME/sequences";
ALL_SEQUENCES_IN_DIR=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) ) # ( "test" ) # manual alternative
SEQUENCES_NAMES=() # gens that have the required size will be added here
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
  timeout $timeOut /bin/time -f "TIME\t%e\tMEM\t%M" $C_COMMAND \
  |& grep "TIME" \
  |& awk '{ printf $2"\t"$4/1024/1024"\n" }' > c_time_mem.txt;

  if [ -e "$FILEC" ]; then
    BYTES_CF=`ls -la $FILEC | awk '{ print $5 }'`;
    BPS=$(echo "scale=3; $BYTES_CF*8 / $BYTES" | bc);
  else 
    BYTES_CF=-1;
    BPS=-1;
  fi
  #
  timeout $timeOut /bin/time -f "TIME\t%e\tMEM\t%M" $D_COMMAND \
  |& grep "TIME" \
  |& awk '{ printf $2"\t"$4/1024/1024"\n" }' > d_time_mem.txt;
  #
  # compare input file to decompressed file; they should have the same sequence
  diff <(tail -n +2 $IN_FILE | tr -d '\n') <(tail -n +2 $FILED | tr -d '\n') > cmp.txt;
  #
  if [[ -s "c_time_mem.txt" ]]; then # if file is not empty...
    C_TIME=`printf "%0.3f\n" $(cat c_time_mem.txt | awk '{ print $1 }')`;
    C_MEME=`printf "%0.3f\n" $(cat c_time_mem.txt | awk '{ print $2 }')`; 
  else
    C_TIME=-1;
    C_MEME=-1;
  fi
  #
  if [[ -s "d_time_mem.txt" ]]; then # if file is not empty...
    D_TIME=`printf "%0.3f\n" $(cat d_time_mem.txt | awk '{ print $1 }')`;
    D_MEME=`printf "%0.3f\n" $(cat d_time_mem.txt | awk '{ print $2 }')`;
  else
    D_TIME=-1;
    D_MEME=-1;
  fi
  #
  VERIFY="0";
  CMP_SIZE=`ls -la cmp.txt | awk '{ print $5}'`;
  if [[ "$CMP_SIZE" != "0" ]]; then CMP_SIZE="1"; fi
  #
  printf "$NAME\t$BYTES\t$BYTES_CF\t$BPS\t$C_TIME\t$C_MEME\t$D_TIME\t$D_MEME\t$CMP_SIZE\t$nrun\t$C_COMMAND\n";
  #
  rm -fr $FILEC $FILED c_tmp_report.txt d_tmp_report.txt c_time_mem.txt d_time_mem.txt
  #
}
#
# === MAIN ===========================================================================
#
LOAD_CSV_DSTOSIZE;

mkdir -p $resultsPath $errPath;
mkdir -p naf_out mbgc_out paq8l_out;

# Initialize variables
timeOut=3600;
numTests=100;
numThreads=8;

# if one or more sizes are choosen, select all SEQUENCES_NAMES with those sizes
for size in "${sizes[@]}"; do
  if [[ "$*" == *"--size $size"* || "$*" == *"-s $size"* ]]; then
    for seq in "${ALL_SEQUENCES_IN_DIR[@]}"; do
        if [[ "${dsToSize[$seq]}" == "$size" ]]; then
            SEQUENCES_NAMES+=("$seq");
        fi
    done
  fi
done

# if one or more gens are choosen, add them to array if they aren't there yet
for seq in "${ALL_SEQUENCES_IN_DIR[@]}"; do
  if [[ "$*" == *"--sequence $seq"* || "$*" == *"-s $seq"* ]]; then
    if ! echo "${SEQUENCES_NAMES[@]}" | grep -q -w "$seq"; then
      SEQUENCES_NAMES+=("$seq");
    fi
  fi
done

#
# if nothing is choosen, all SEQUENCES_NAMES will be selected
if [ ${#SEQUENCES_NAMES[@]} -eq 0 ]; then
  SEQUENCES_NAMES=("${ALL_SEQUENCES_IN_DIR[@]}");
fi

# Parse other command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --timeout|-to)
      timeOut="$2"
      shift # past argument
      shift # past value
      ;;
    --num-tests|-n)
      numTests="$2"
      shift # past argument
      shift # past value
      ;;
    --threads|-t)
      numThreads="$2"
      shift # past argument
      shift # past value
      ;;
    *) 
      # Ignore any other arguments
      shift
      ;;
  esac
done

#
# ------------------------------------------------------------------------------
#
run=1;
for sequenceName in "${SEQUENCES_NAMES[@]}"; do
    sequence="$sequencesPath/$sequenceName";
    #
    ds_id=$(($(grep -n -w "$sequenceName" dsToSize.csv | cut -d ":" -f 1)-1))
    size=${dsToSize[$sequenceName]};
    # num_runs_to_repeat=1;
    #
    output_file_ds="$resultsPath/optim-bench-raw-ds${ds_id}-${size}.txt";
    #
    # --- RUN sequence TESTS ---------------------------------------------------------------------------
    #
    printf "DS$ds_id - $sequenceName - $size \nPROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tD_TIME (s)\tD_MEM (GB)\tDIFF\tRUN\tC_COMMAND\n";
    #

    # PARAMETERS COMMON TO CM AND RM
    NB_C_lst=( {1..13} ) # context model size
    NB_I_lst=( {0,1,2} ) # manages inverted repeats
    NB_G_lst=($(seq 0 0.1 0.9)) # gamma

    # CM PARAMETERS
    NB_D_lst=( {1..5000} ) # alpha=1/NB_D => parameter estimator
    NB_S_lst=( {1..20} )
    NB_R_lst=( {0,1} )
    NB_E_lst=( {1..5000} )
    NB_A_lst=($(seq 0 0.1 0.9))

    # RM PARAMETERS
    NB_R_lst=( {1..100} )
    NB_B_lst=($(seq 0.9 0.01 0.99))
    NB_L_lst=({9000..10000}) # has dependency with NB_B
    NB_W_lst=($(seq 0 0.1 0.9)) # initial weight for repeat classes
    NB_Y_lst=({0..50}) # max cache size

    for ((i=1; i<=numTests; i++)); do
      min_cms=0;
      max_cms=5;

      num_cms=$((RANDOM % (max_cms - min_cms + 1) + min_cms));

      CM="";
      for ((j=1; j<=num_cms; j++)); do
        # randomly chosen cm parameter values -cm 1:1:0:0.9/0:0:0:0
        NB_C=${NB_C_lst[$((RANDOM % ${#NB_C_lst[@]}))]};
        NB_D=${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}; 
        NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]}; 
        NB_G=${NB_G_lst[$((RANDOM % ${#NB_G_lst[@]}))]};
        NB_S=${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]};
        NB_R=${NB_R_lst[$((RANDOM % ${#NB_R_lst[@]}))]};
        NB_E=1 # ${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]};
        NB_A=${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]};

        CM+="-cm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_R}:${NB_E}:${NB_A} ";
      done

      # randomly chosen rm parameter values
      NB_R=${NB_R_lst[$((RANDOM % ${#NB_R_lst[@]}))]};
      NB_C=12 # ${NB_C_lst[$((RANDOM % ${#NB_C_lst[@]}))]}; 
      NB_B=${NB_B_lst[$((RANDOM % ${#NB_B_lst[@]}))]}; 
      NB_L=7 # ${NB_L_lst[$((RANDOM % ${#NB_L_lst[@]}))]};
      NB_G=0.7 # ${NB_G_lst[$((RANDOM % ${#NB_G_lst[@]}))]};
      NB_I=1 # ${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]};
      NB_W=0.06 # ${NB_W_lst[$((RANDOM % ${#NB_W_lst[@]}))]};
      NB_Y=2 # ${NB_Y_lst[$((RANDOM % ${#NB_Y_lst[@]}))]};

      RM="-rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}";

      RUN_TEST "JARVIS3_BIN" "$sequence.seq" "$sequence.seq.jc" "$sequence.seq.jc.jd" "${binPath}JARVIS3 --threads $numThreads $CM $RM $sequence.seq" "${binPath}JARVIS3 -d $sequence.seq.jc" "$run"; run=$((run+1));

    done
done
# 
