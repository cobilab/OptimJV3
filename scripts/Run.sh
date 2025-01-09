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
  echo "-h|--help......................................Show this";
  echo "-v|--view-ds|--view-datasets...View sequence names, size";
  echo "           of each in bytes, MB, and BG, and their group";
  echo "-s|--seq|--sequence..........Select sequence by its name";
  echo "-sg|--sequence-grp|--seq-group.Select group of sequences";
  echo "                                           by their size";
  echo "-a|-ga|--genetic-algorithm...Define (folder) name of the";
  echo "                                       genetic algorithm";
  echo "-s|--seq|--sequence.................Select sequence name";
  echo "-sg|--seq-grp|--sequence-group.....Select sequence group";
  echo "-ds|--dataset......Select sequence by its dataset number";
  echo "-dr|--drange|--dsrange|--dataset-range............Select";
  echo "                   sequences by range of dataset numbers";
  echo "-ps|--psize|--population|--population-size........Define";
  echo "                                         population size";
  echo "-t|--nthreads...........num of threads to run JARVIS3 in"; 
  echo "                                                parallel";
  echo "-sd|--seed.....................Define pseudo-random seed";
  echo "-si|--seed-increment...............Define seed increment";
  echo "                                                        ";
  echo " Program options (run) ---------------------------------";
  echo "                                                        ";
  echo "-t|--nthreads...........num of threads to run JARVIS3 in"; 
  echo "                                                parallel";
  echo "                                                        ";
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
  gnum="$7";
  #
  c_time_mem="${sequenceName}${output_ext}c_time_mem.txt";
  #
  BYTES=`ls -la $IN_FILE | awk '{ print $5 }'`;
  #
  # COMPRESSION
  # https://man7.org/linux/man-pages/man1/time.1.html
  # %e: (Not in tcsh(1).)  Elapsed real time (in seconds).
  # %M: Maximum resident set size of the process during its lifetime, in Kbytes, HOWEVER
  # Kbyte/1024/1024 => Gigabyte
  timeout "$timeOut" /bin/time -o $c_time_mem -f "TIME\t%e\tMEM\t%M" $C_COMMAND;
  errorStatus=$?
  # errorStatus=$(( $(cat $c_time_mem | wc -l) != 1 ))
  echo "time (s) and mem (GB)"; cat $c_time_mem
  #
  # a cmd is valid if compressed file exists, compression stats is not empty, non error status and did not use too much RAM
  BYTES_CF=`ls -la $FILEC | awk '{ print $5 }'`;
  BPS=$(echo "scale=3;$BYTES_CF*8/$BYTES" | bc)
  #
  C_TIME=`printf "%0.3f\n" $(cat $c_time_mem | grep TIME | awk '{ print $2 }')`; 
  C_MEME=`printf "%0.3f\n" $(cat $c_time_mem | grep TIME | awk '{ print $4/1024/1024 }')`;
  #
  tooMuchMEM=$(echo "$C_MEME > $maxGBperCmd"|bc)
  (( $tooMuchMEM )) && VALIDITY=$maxGBperCmd || VALIDITY=$errorStatus
  #
  pattern=" -o ../../sequences/*.seq.jc ";
  printf "$NAME\t$VALIDITY\t$BYTES\t$BYTES_CF\t$BPS\t$C_TIME\t$C_MEME\t$gnum\t${C_COMMAND/$pattern}\n" 1>> "$resOutput";
  #
  rm -fr $c_time_mem $FILEC
  unset BYTES_CF BPS C_TIME C_MEM
  #
}
#
# === MAIN ===========================================================================
#
# default values
#
configJson="../config.json"
#
sizes=("grp1" "grp2" "grp3" "grp4" "grp5"); # to be able to filter SEQUENCES to run by size
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
#
timeOut=3600;
#
if [ $(w | wc -l) -gt 3 ]; then # if there is more than one user registered in the system (example: sapiens server)
  nthreads=$(( $(nproc --all)/3 )) 
  maxGBperCmd="2.5"
else # server with only one user
  nthreads=$(( $(nproc --all)-2 ))
  maxFreeGB=$(awk '/MemFree/ {printf "%.3f \n", $2/1024/1024 }' /proc/meminfo)
  maxGBperCmd=$(echo "scale=3;$maxFreeGB/$nthreads" | bc)
fi
#
ga="ga";
#
# remove output files and dirs from last time this script was executed
rm -fr *c_time_mem.txt
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
    --genetic-algorithm|--algorithm|--ga|-ga|-a)
      ga="$2";
      shift 2; 
      ;;
    --sequence|--seq|-s)
      sequence="$2";
      FIX_SEQUENCE_NAME "$sequence"
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
      shift 2;
      ;;
    --timeout|-to)
      timeOut="$2"
      shift 2;
      ;;
    --nthreads|-t)
      nthreads="$2";
      shift 2;
      ;;
    *) 
      echo "Invalid option: $1"
      exit 1;
      ;;
  esac
done
#
if [ ${#SEQUENCES[@]} -eq 0 ]; then
  SEQUENCES=( "${ALL_SEQUENCES[@]}" );
fi
#
# first generation tends to use more memory than other generations
if [ $gnum -eq 1 ]; then
  [ $nthreads -gt $(($(nproc --all)/2)) ] && nthreads=$(( $nthreads-2 ))
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
    dsFolder="../${dsX}/$ga";
    cmdsScriptInput="$dsFolder/g${gnum}.sh"; 
    CHECK_INPUT "$cmdsScriptInput";
    #
    resOutput_header="$dsFolder/g${gnum}_header.txt";
    printf "$dsX - $sequenceName - generation${gnum} \nPROGRAM\tVALIDITY\tBYTES\tBYTES_CF\tBPS\tC_TIME (s)\tC_MEM (GB)\tBIRTH_GEN\tC_COMMAND\n" 1> "$resOutput_header";
    #
    # run tests from generation $gnum
    sequence="$sequencesPath/$sequenceName";
    rm -fr $sequence.*.jc # remove compressed sequence
    echo "sequence to compress: $sequence.seq";
    echo "start splitting and running cmds from $cmdsScriptInput file...";
    #
    # remove old splitted scripts if there are any 
    rm -fr $dsFolder/*"_splitted_"*.sh;
    #
    # save old splitted results if there are any
    savedFile="$dsFolder/g${gnum}_saved.txt"
    cat $dsFolder/*"_splitted_"*.txt >> $savedFile
    rm -fr $dsFolder/*"_splitted_"*.txt;
    #
    # split child cmds
    numCmds=$(cat $cmdsScriptInput | wc -l);
    extraLine=$(( $numCmds%$nthreads == 0 ? 0 : 1 ));
    maxNumCmds=$(echo "$numCmds/$nthreads + $extraLine" | bc);
    split --lines=$maxNumCmds "$cmdsScriptInput" "$dsFolder/g${gnum}_splitted_" --additional-suffix ".sh"
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
        cmd_b4lastArg="$(echo $cmd | awk '{$NF=""; print}')";
        cmd_oFile="-o $sequence.$output_ext.seq.jc";
        cmd_lastArg="$(echo $cmd | awk '{printf $NF}')";
        cmd_with_o_flag="${cmd_b4lastArg} ${cmd_oFile} ${cmd_lastArg}";
        echo "cmd that will compress : $cmd_with_o_flag"
        #
        d_cmd="none"; # we only want to optimize compression, not decompression
        #
        RUN_TEST "JV3_${ga}_${num_cms}cms_${num_rms}rms" "$sequence.seq" "$sequence.$output_ext.seq.jc" "$sequence.$output_ext.seq.jc.jd" "${cmd_with_o_flag}" "${d_cmd}" "$gnum"
        #
        # this prevents from having to rerun the whole population if this script is interrupted
        cmdsScriptInputTMP="$dsFolder/g${gnum}TMP.sh"; 
        awk -v x="${C_COMMAND/$pattern}" '! index($0,x)' $cmdsScriptInput > $cmdsScriptInputTMP && mv $cmdsScriptInputTMP $cmdsScriptInput
        splittedScriptTMP="${splittedScript/.sh/TMP.sh}"
        awk -v x="${C_COMMAND/$pattern}" '! index($0,x)' $cmdsScriptInput > $splittedScriptTMP && mv $splittedScriptTMP $splittedScript
        #
        echo "results stored in: $resOutput";
      done < <(cat $splittedScript) ) &
    done
    #
    # wait until all splitted scripts have been executed in parallel
    wait;
    #
    # merge results
    resOutput_body="$dsFolder/g${gnum}_splitted_*.txt";
    evalFolder="$dsFolder/eval"
    mkdir -p $evalFolder
    resOutput="$evalFolder/rawRes.tsv";
    cat $resOutput_header $resOutput_body $savedFile > $resOutput 2> /dev/null
    #
    # remove splitted cmd scripts, children script, header, and file with other results saved from last execution
    rm -fr $dsFolder/*"_splitted_"* $cmdsScriptInput $resOutput_header $savedFile;
done
