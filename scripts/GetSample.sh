#!/bin/bash
#
function SHOW_HELP() {
  echo " -------------------------------------------------------";
  echo "                                                        ";
  echo " OptimJV3 - optimize JARVIS3 CM and RM parameters       ";
  echo "                                                        ";
  echo " Program options ---------------------------------------";
  echo "                                                        ";
  echo "-h|--help......................................Show this";
  echo "-s|--sequence..................Choose sequence name/file";
  echo "-sp|--start-percentage.....Define Percentage of the full";
  echo "                            sequence where sample begins";
  echo "-sz|-mb|--size-mb.....................Define sample size";
  echo "-so|--sample-output........Define sample output filename";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
function FIX_SEQUENCE_NAME() {
    sequence="$1"
    sequence=$(echo $sequence | sed 's/.mfasta//g; s/.fasta//g; s/.mfa//g; s/.fa//g; s/.seq//g')
    #
    if [ "${sequence^^}" == "CY" ]; then 
        sequence="CY"
    elif [ "${sequence^^}" == "CASSAVA" ]; then 
        sequence="TME204.HiFi_HiC.haplotig1"
    elif [ "${sequence^^}" == "HUMAN" ]; then
        sequence="chm13v2.0"
    fi
}
#
configJson="../config.json"
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
        SHOW_HELP;
        exit;
        ;;
    -s|--sequence)
        FIX_SEQUENCE_NAME "${2%.*}"
        sequence="$sequence.seq"
        shift 2;
        ;;
    -sp|--start-percentage)
        startPerc="$2"
        shift 2;
        ;;
    -sz|-mb|--size-mb)
        sampleSize=$(echo "$2 * 2^20" | bc)
        shift 2;
        ;;
    -so|--sample-output)
        sampleFile="${2%.*}.seq"
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
# === example: start position of 100MB human sequence starts at 40% to avoid telomeres ===
# echo "scale=3;3117292070*0.4 + 1"|bc = 1246916829.0 -> start
# echo "3117292070*0.4 + 100*2^20"|bc = 1351774428.0 -> end
#
fullSize=$(ls -l $sequencesPath/$sequence | awk '{print $5}')
start=$(echo "scale=0;$fullSize*$startPerc + 1" | bc | cut -d'.' -f1)
end=$(echo "scale=0;$fullSize*$startPerc + $sampleSize" | bc | cut -d'.' -f1)
cat $sequencesPath/$sequence | cut -c $start-$end | tr -d '\n' > $sequencesPath/$sampleFile
