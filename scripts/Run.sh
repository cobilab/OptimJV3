#!/bin/bash
#
# ==============================================================================
#
function SHOW_HELP() {
  echo " -------------------------------------------------------";
  echo "                                                        ";
  echo " OptimJV3 - optimize JARVIS3 CM and RM parameters       ";
  echo "                                                        ";
  echo " Program options ---------------------------------------";
  echo "                                                        ";
  echo " --help|-h.....................................Show this";
  echo " --view-datasets|--view-ds|-v....View sequences and size"; 
  echo "                                                 of each";
  echo "--sequence|--seq|-s..........Select sequence by its name";
  echo "--sequence-group|--seq-grp|-sg.Select group of sequences";
  echo "                                           by their size";
  echo "--dataset|-ds......Select sequence by its dataset number";
  echo "--dataset-range|--dsrange|--drange|-dr............Select";
  echo "                   sequences by range of dataset numbers";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
# ==============================================================================
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
  # COMPRESSION
  # https://man7.org/linux/man-pages/man1/time.1.html
  # %e: (Not in tcsh(1).)  Elapsed real time (in seconds).
  # %M: Maximum resident set size of the process during its lifetime, in Kbytes, HOWEVER
  # Kbyte/1024/1024 => Gibyte
  c_time_mem_tmp="${sequenceName}${output_ext}c_time_mem_tmp.txt";
  c_time_mem="${c_time_mem_tmp//_tmp.txt/.txt}";
  timeout "$timeOut" /bin/time -o $c_time_mem_tmp -f "TIME\t%e\tMEM\t%M" $C_COMMAND;
  cat "$c_time_mem_tmp" | grep "TIME" | awk '{ printf $2"\t"$4/1024/1024"\n" }' 1> "${c_time_mem}";
  rm -fr $c_time_mem_tmp;
  #
  if [ -e "$FILEC" ]; then
    BYTES_CF=`ls -la $FILEC | awk '{ print $5 }'`;
    BPS=$(echo "scale=3; $BYTES_CF*8 / $BYTES" | bc);
  else 
    BYTES_CF=-1;
    BPS=-1;
  fi
  #
  # DECOMPRESSION is not needed for optimization
  d_time_mem="${sequenceName}${output_ext}d_time_mem.txt";
  printf "%d\t%d\n" -1 -1 > $d_time_mem;
  #
  # CMP file is not needed for optimization
  cmp="${sequenceName}${output_ext}cmp.txt";
  touch $cmp;
  #
  # register C_TIME and C_MEME 
  if [[ -s "$c_time_mem" ]]; then # if file is not empty...
    C_TIME=`printf "%0.3f\n" $(cat $c_time_mem | awk '{ print $1 }')`; 
    C_MEME=`printf "%0.3f\n" $(cat $c_time_mem | awk '{ print $2 }')`; 
  else
    C_TIME=-1;
    C_MEME=-1;
  fi
  #
  # register D_TIME and D_MEME
  if [[ -s "$d_time_mem" ]]; then # if file is not empty...
    D_TIME=`printf "%0.3f\n" $(cat $d_time_mem | awk '{ print $1 }')`;
    D_MEME=`printf "%0.3f\n" $(cat $d_time_mem | awk '{ print $2 }')`;
  else
    D_TIME=-1;
    D_MEME=-1;
  fi
  #
  VERIFY="0";
  CMP_SIZE=`ls -la $cmp | awk '{ print $5}'`;
  if [[ "$CMP_SIZE" != "0" ]]; then CMP_SIZE="1"; fi
  #
  printf "$NAME\t$BYTES\t$BYTES_CF\t$BPS\t$C_TIME\t$C_MEME\t$D_TIME\t$D_MEME\t$CMP_SIZE\t$nrun\t$C_COMMAND\n" 1>> "$resOutput";
  #
  rm -fr $c_time_mem $d_time_mem $cmp;   
  rm -fr $FILEC $FILED;
  #
}
#
# === MAIN ===========================================================================
#
# default values
#
jv3Path="../jv3/";
sizes=("grp1" "grp2" "grp3" "grp4" "grp5"); # to be able to filter SEQUENCES to run by size
sequencesPath="../../sequences";
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
#
timeOut=3600;
nthreads=$(( $(nproc --all)-2 ));
#
# remove output files and dirs from last time Run.sh was executed
rm -fr *c_time_mem.txt *d_time_mem.txt *cmp.txt; 
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
      SEQUENCES+=( "$sequence" );
      shift 2; 
      ;;
    --sequence-group|--sequence-grp|--seq-group|--seq-grp|-sg)
      size="$2";
      SEQUENCES+=( $(awk '/[[:space:]]'$size'/ { print $2 }' "$ds_sizesBase2") );
      shift 2; 
      ;;
    --dataset|-ds)
      dsnum=$(echo "$2" | tr -d "dsDS");
      SEQUENCES+=( "$(awk '/DS'$dsnum'[[:space:]]/{print $2}' "$ds_sizesBase2")" );
      shift 2;
      ;;
    --dataset-range|--dsrange|--drange|-dr)
      input=( $(echo "$2" | sed 's/[:/]/ /g') );
      sortedInput=( $(printf "%s\n" ${input[@]} | sort -n ) );
      dsmin="${sortedInput[0]}";
      dsmax="${sortedInput[1]}";
      SEQUENCES+=( $(awk -v m=$dsmin -v M=$dsmax 'NR>=1+m && NR <=1+M {print $2}' "$ds_sizesBase2") );
      shift 2;
      ;;
    --gen-num|-g)
      gnum="$2";
      shift # past argument
      shift # past value
      ;;
    --timeout|-to)
      timeOut="$2"
      shift
      shift
      ;;
    --threads|-t)
      nthreads="$2";
      shift
      shift
      ;;
    *) 
      # ignore any other arguments
      shift
      ;;
  esac
done
#
if [ ${#SEQUENCES[@]} -eq 0 ]; then
  SEQUENCES=( "${ALL_SEQUENCES[@]}" );
fi
#
# ------------------------------------------------------------------------------
#
for sequenceName in "${SEQUENCES[@]}"; do
    echo "--- sequence: $sequenceName -----------------------------------------------";
    #
    dsX=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    size=$(awk '/'$sequenceName'[[:space:]]/ { print $NF }' "$ds_sizesBase2");
    #
    dsFolder="../${dsX}";
    cmdsScriptInput="$dsFolder/g${gnum}.sh"; 
    CHECK_INPUT "$cmdsScriptInput";
    #
    resOutput_header="$dsFolder/g${gnum}_header.txt";
    printf "$dsX - $sequenceName \nPROGRAM\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tD_TIME (s)\tD_MEM (GB)\tDIFF\tRUN\tC_COMMAND\n" 1> "$resOutput_header";
    #
    # run tests from generation $gnum
    sequence="$sequencesPath/$sequenceName";
    echo "sequence to compress: $sequence.seq";
    echo "start splitting and running cmds from $cmdsScriptInput file...";
    #
    # split child cmds
    numCmds=$(cat $cmdsScriptInput | wc -l);
    maxNumCmds=$(echo "$numCmds/$nthreads + 1" | bc);
    split --lines=$maxNumCmds "$dsFolder/g${gnum}.sh" "$dsFolder/g${gnum}_splitted_" --additional-suffix ".sh"
    chmod +x $dsFolder/*"_splitted_"*;
    #
    splittedScripts=( $(ls $dsFolder/*"_splitted_"*) );
    #
    echo "the following splitted scripts are going to be executed:";
    for ss in ${splittedScripts[@]}; do echo "$ss [ $(cat $ss | wc -l) cmds ]"; done | nl
    #
    for splittedScript in ${splittedScripts[@]}; do
      ( while IFS= read -r cmd; do
        resOutput="${splittedScript//.sh/.txt}";
        #
        num_cms=$(echo $cmd | grep -o "cm" | wc -l); # can go from 1 to 5
        num_rms=$(echo $cmd | grep -o "rm" | wc -l); # can go from 0 to 2
        #
        output_ext=$(echo "$splittedScript" | awk -F 'splitted_|\.sh' '{print $2}');
        #
        # ${jv3Path}JARVIS3 $CM $RM -o $sequence.$output_ext.seq.jc $sequence.seq
        cmd_b4lastArg="$(echo $cmd | awk '{$NF=""; print}')";
        cmd_oFile="-o $sequence.$output_ext.seq.jc";
        cmd_lastArg="$(echo $cmd | awk '{printf $NF}')";
        cmd="${cmd_b4lastArg} ${cmd_oFile} ${cmd_lastArg}";
        echo "cmd that will compress : $cmd"
        #
        d_cmd="none"; # we only want to optimize compression, not decompression
        #
        RUN_TEST "JV3bin_${num_cms}cms_${num_rms}rms" "$sequence.seq" "$sequence.$output_ext.seq.jc" "$sequence.$output_ext.seq.jc.jd" "${cmd}" "${d_cmd}" "$gnum"
        #
        echo "results stored in: $resOutput";
      done < <(cat $splittedScript) ) &
    done
    wait; # wait until all splitted scripts, that compress a specific sequence, are executed in parallel
    #
    # merge results
    resOutput_body="$dsFolder/g${gnum}_splitted_*.txt";
    resOutput="$dsFolder/g${gnum}_raw.tsv";
    cat $resOutput_header $resOutput_body > $resOutput;
    #
    # remove splitted cmd scripts and header
    rm -fr $dsFolder/*"_splitted_"* $resOutput_header;
    #
    # remove splitted results and header 
    # rm -fr $resOutput_body $resOutput_header;
    #
done