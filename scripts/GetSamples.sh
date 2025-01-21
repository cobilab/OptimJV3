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
  echo "-s|--seq|--sequence............Choose sequence name/file";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
configJson="../config.json"
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
sequence="chm13v2.0.seq"
sample100mb="human100MB.seq"
sample50mb="human50MB.seq"
sample25mb="human25MB.seq"
sample12d5mb="human12d5MB.seq"
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
        SHOW_HELP;
        exit;
        ;;
    -s|--sequence)
        sequence="${2%.*}.seq"
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done

if [[ "$sequence" == "cassava"* ]] || [[ "$sequence" == "TME204.HiFi_HiC.haplotig1"* ]]; then
    sequence="TME204.HiFi_HiC.haplotig1.seq"
    sample100mb="cassava100MB.seq"
    sample50mb="cassava50MB.seq"
    sample25mb="cassava25MB.seq"
    sample12d5mb="cassava12d5MB.seq"
elif [[ "$sequence" != "human"* ]] && [[ "$sequence" != "chm13v2.0"* ]]; then
    sample100mb="${sequence%.*}100MB.seq"
    sample50mb="${sequence%.*}50MB.seq"
    sample25mb="${sequence%.*}25MB.seq"
    sample12d5mb="${sequence%.*}12d5MB.seq"
fi
# echo $sequence $sample100mb $sample50mb $sample25mb $sample12d5mb
#
# === Start position of 100MB sequence starts at 40% to avoid telomeres ===
# example: human
# echo "scale=3;3117292070*0.4 + 1"|bc = 1246916829.0 -> start
# echo "3117292070*0.4 + 100*2^20"|bc = 1351774428.0 -> end
size=$(ls -l $sequencesPath/$sequence | awk '{print $5}')
start=$(echo "scale=0;$size*0.4 + 1" | bc | cut -d'.' -f1)
end=$(echo "scale=0;$size*0.4 + 100*2^20" | bc | cut -d'.' -f1)
cat $sequencesPath/$sequence | cut -c $start-$end | tr -d '\n' > $sequencesPath/$sample100mb
#
# === First 50% of 100MB sequence ===
# 1 -> start
# echo "104857600*0.5"|bc = 52428800.0 -> end
cat $sequencesPath/$sample100mb | cut -c 1-52428800 | tr -d '\n' > $sequencesPath/$sample50mb
# === First 25% of 100MB sequence ===
# 1 -> start
# echo "104857600*0.25"|bc = 26214400.0 -> end
cat $sequencesPath/$sample100mb | cut -c 1-26214400 | tr -d '\n' > $sequencesPath/$sample25mb
#
# === First 25% of 100MB sequence ===
# 1 -> start
# echo "104857600*0.125"|bc = 13107200.000 -> end
cat $sequencesPath/$sample100mb | cut -c 1-13107200 | tr -d '\n' > $sequencesPath/$sample12d5mb
