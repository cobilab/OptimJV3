#!/bin/bash

#!/bin/bash
##
resultsPath="results";
bin_path="bin/";
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
  /bin/time -f "TIME\t%e\tMEM\t%M" $C_COMMAND \
  |& grep "TIME" \
  |& tr '.' ',' \
  |& awk -v dividendo="$dividendo" '{ printf $2/dividendo"\t"$4/1024/1024"\n" }' > c_time_mem.txt;
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
  |& awk -v dividendo="$dividendo" '{ printf $2/dividendo"\t"$4/1024/1024"\n" }' > d_time_mem.txt;
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
  printf "$NAME\t$BYTES\t$BYTES_CF\t$BPS\t$C_TIME\t$C_MEME\t$D_TIME\t$D_MEME\t$CMP_SIZE\t$nrun\t$CM\n" | tee -a "$resultsPath/optim-bench-results-raw.txt";
  #
  rm -fr c_tmp_report.txt d_tmp_report.txt c_time_mem.txt d_time_mem.txt
}
#
# === MAIN ===========================================================================
#
rm -fr "$resultsPath/optim-bench-results-raw.txt";
mkdir -p $resultsPath;

# read the command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --genome|-g)
            genome="$2"
            shift # past argument
            shift # past value
            ;;
        --time|-t) # TODO: INCLUIR TIMEOUT
            time="$2"
            shift
            shift
            ;;
        *) # unknown option
            shift
            ;;
    esac
done

# check if the sequence exists in directory
if [[ ! -f "$genome.seq" ]]; then 
    echo "That file does not exist in the directory"
    exit 1;
fi

#
# --- RUN GENOME TESTS ---------------------------------------------------------------------------
#

dividendo=1;
str_time="s";

printf "$genome \nPROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME ($str_time)\tC_MEM (GB)\tD_TIME ($str_time)\tD_MEM (GB)\tDIFF\tRUN\n" | tee -a "$resultsPath/optim-bench-results-raw.txt";

NB_C_lst=( {1..14} ) # context model size
NB_D_lst=( {1..5000} ) # alpha=1/NB_D => parameter estimator
NB_I_lst=( {0,1,2} ) # manages inverted repeats
NB_G_lst=($(seq 0 0.1 0.9)) # gamma
NB_S_lst=( {1..20} )
NB_R_lst=( {0,1} )
NB_E_lst=( {1..5000} )
NB_A_lst=($(seq 0 0.1 0.9))


for i in {1..100}; do

  NB_C=$((RANDOM % ${NB_C_lst[-1]} + ${NB_C_lst[0]}))
  NB_D=1 # alpha=1/NB_D => parameter estimator
  NB_I=0 # manages inverted repeats
  NB_G=0 # gamma
  NB_S=1
  NB_R=0
  NB_E=1
  NB_A=0

  CM="-cm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_R}:${NB_E}:${NB_A}"
done


RUN_TEST "JARVIS3_BIN" "$genome.seq" "$genome.seq.jc" "$genome.seq.jc.jd" "${bin_path}JARVIS3 $CM $genome.seq" "${bin_path}JARVIS3 -d $genome.seq.jc" "$run"; run=$((run+1));
