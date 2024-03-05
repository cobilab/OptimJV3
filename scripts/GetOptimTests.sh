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

sequencesPath="../../sequences";
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
  BYTES=`ls -la $IN_FILE | awk '{ print $5 }'`;
  #
  # COMPRESSAO
  # https://man7.org/linux/man-pages/man1/time.1.html
  # %e: (Not in tcsh(1).)  Elapsed real time (in seconds).
  # %M: Maximum resident set size of the process during its lifetime, in Kbytes.
  timeout "$timeOut" /bin/time -f "TIME\t%e\tMEM\t%M" $C_COMMAND \
  |& grep "TIME" \
  |& awk '{ printf $2"\t"$4/1024/1024"\n" }' > ${sequenceName}${output_ext}c_time_mem.txt;

  if [ -e "$FILEC" ]; then
    BYTES_CF=`ls -la $FILEC | awk '{ print $5 }'`;
    BPS=$(echo "scale=3; $BYTES_CF*8 / $BYTES" | bc);
  else 
    BYTES_CF=-1;
    BPS=-1;
  fi
  #
  # DESCOMPRESSAO
  timeout "$timeOut" /bin/time -f "TIME\t%e\tMEM\t%M" $D_COMMAND \
  |& grep "TIME" \
  |& awk '{ printf $2"\t"$4/1024/1024"\n" }' > d_time_mem.txt;
  #
  # compare input file to decompressed file; they should have the same sequence
  diff <(tail -n +2 $IN_FILE | tr -d '\n') <(tail -n +2 $FILED | tr -d '\n') > cmp.txt;
  #
  if [[ -s "${sequenceName}${output_ext}c_time_mem.txt" ]]; then # if file is not empty...
    C_TIME=`printf "%0.3f\n" $(cat ${sequenceName}${output_ext}c_time_mem.txt | awk '{ print $1 }')`; 
    C_MEME=`printf "%0.3f\n" $(cat ${sequenceName}${output_ext}c_time_mem.txt | awk '{ print $2 }')`; 
  else
    C_TIME=-1;
    C_MEME=-1;
  fi
  #
  if [[ -s "${sequenceName}${output_ext}d_time_mem.txt" ]]; then # if file is not empty...
    D_TIME=`printf "%0.3f\n" $(cat ${sequenceName}${output_ext}d_time_mem.txt | awk '{ print $1 }')`;
    D_MEME=`printf "%0.3f\n" $(cat ${sequenceName}${output_ext}d_time_mem.txt | awk '{ print $2 }')`;
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
  rm -fr $FILEC $FILED; # c_tmp_report.txt d_tmp_report.txt; # ${sequenceName}${output_ext}c_time_mem.txt ${sequenceName}${output_ext}d_time_mem.txt;
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
numTests=50;
numThreads=8;
output=false;
output_ext="";

# if one or more sizes are choosen, select all SEQUENCES_NAMES with those sizes
for size in "${sizes[@]}"; do
  if [[ "$*" == *"--size $size"* || "$*" == *"-sz $size"* ]]; then
    for seq in "${ALL_SEQUENCES_IN_DIR[@]}"; do
        if [[ "${dsToSize[$seq]}" == "$size" ]]; then
            SEQUENCES_NAMES+=("$seq");
        fi
    done
  fi
done

# if one or more sequences are choosen, add them to array if they aren't there yet
for seq in "${ALL_SEQUENCES_IN_DIR[@]}"; do
  if [[ "$*" == *"--sequence $seq"* || "$*" == *"--seq $seq"* || "$*" == *"-sq $seq"* ]]; then
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

echo ${SEQUENCES_NAMES[@]}

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
    --output|-o)
      output=true;
      output_ext="$2";
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
    ds_id=$(($(grep -n -w "$sequenceName" dsToSize.csv | cut -d ":" -f 1)-1));
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
    NB_I_lst=(1) # (integer {0,1,2}) manages inverted repeats

    # CM PARAMETERS
    # -cm [NB_C_cm]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_R]:[NB_E]:[NB_A]
    NB_C_cm_lst=( {1..5} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( 1 2 5 10 20 50 100 200 500 1000 2000 ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_G_cm_lst=(0.9) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..6} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant model (stcm?)
    NB_E_lst=( 1 2 5 10 20 50 100 ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_A_lst=($(seq 0 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)

    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_C_rm_lst=(12 13) # RM size. higher values -> more RAM -> better compression
    NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of repeat models
    NB_B_lst=($(seq 0.5 0.1 0.9)) # (real (0;1]) beta. discards or keeps a repeat model
    NB_L_lst=( {4..9} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=(0.7) # (real [0;1)) gamma; decayment forgetting factor
    NB_W_lst=(0.06) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=(2) # (integer {0}, [1;50]) max cache size

    # otimizacao aleatoria
    for ((i=1; i<=numTests; i++)); do
      min_cms=1;
      max_cms=3;

      # can go from 1 to 5
      num_cms=$((RANDOM % (max_cms - min_cms + 1) + min_cms));

      CM="";
      for ((j=1; j<=num_cms; j++)); do
        # randomly chosen cm parameter values -cm 1:1:0:0.9/0:0:0:0
        NB_C=${NB_C_cm_lst[$((RANDOM % ${#NB_C_cm_lst[@]}))]};
        NB_D=${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}; 
        NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]}; 
        NB_G=${NB_G_cm_lst[$((RANDOM % ${#NB_G_cm_lst[@]}))]};
        NB_S=${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]};
        NB_R=${NB_R_cm_lst[$((RANDOM % ${#NB_R_cm_lst[@]}))]};
        NB_E=${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]};
        NB_A=${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]};

        CM+="-cm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_E}:${NB_R}:${NB_A} ";
      done

      min_rms=0;
      max_rms=1;

      # can go from 0 to 2
      num_rms=$((RANDOM % (max_rms - min_rms + 1) + min_rms));

      RM="";
      for ((j=1; j<=num_rms; j++)); do
        # randomly chosen rm parameter values
        NB_R=${NB_R_rm_lst[$((RANDOM % ${#NB_R_rm_lst[@]}))]};
        NB_C=${NB_C_rm_lst[$((RANDOM % ${#NB_C_rm_lst[@]}))]}; 
        NB_B=${NB_B_lst[$((RANDOM % ${#NB_B_lst[@]}))]}; 
        NB_L=${NB_L_lst[$((RANDOM % ${#NB_L_lst[@]}))]};
        NB_G=${NB_G_rm_lst[$((RANDOM % ${#NB_G_rm_lst[@]}))]}; 
        NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]};
        NB_W=${NB_W_lst[$((RANDOM % ${#NB_W_lst[@]}))]};
        NB_Y=${NB_Y_lst[$((RANDOM % ${#NB_Y_lst[@]}))]};

        RM+="-rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y} ";
      done

      if $output; then
        RUN_TEST "JV3bin_${num_cms}cms_${num_rms}rms" "$sequence.seq" "$sequence.$output_ext.seq.jc" "$sequence.$output_ext.seq.jc.jd" "${binPath}JARVIS3_output $CM $RM -o $sequence.$output_ext.seq.jc $sequence.seq" "${binPath}JARVIS3_output -d $sequence.$output_ext.seq.jc" "$run"; run=$((run+1));
      else
        RUN_TEST "JV3bin_${num_cms}cms_${num_rms}rms" "$sequence.seq" "$sequence.seq.jc" "$sequence.seq.jc.jd" "${binPath}JARVIS3_output $CM $RM $sequence.seq" "${binPath}JARVIS3_output -d $sequence.seq.jc" "$run"; run=$((run+1));
      fi
    done

    # otimizacao evolucionaria/genetica
    # population_size=100
    # mutation_rate=0.1
    # num_generations=10
done

