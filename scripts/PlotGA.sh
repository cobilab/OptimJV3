#!/usr/bin/env bash
#
# default variables
POPULATION=100;
bestN=$POPULATION;
first_gen=0;
last_gen=12;
sizes=("xs" "s" "m" "l" "xl");
dsX=1;
size="xs";
#
csv_dsToSize="dsToSize.csv";
declare -A csv_dsToSize;
#
plots="../plots";
mkdir -p $plots;
#
# ==============================================================================
#
function CHECK_INPUT () {
  FILE=$1
  if [ -f "$FILE" ]; then
    echo "Input filename: $FILE"
  else
    echo -e "\e[31mERROR: input file not found ($FILE)!\e[0m";
    exit;
  fi
}
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
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --dataset|-ds)
        dsX="$2";
        size=$(tail -n +2 $csv_dsToSize | nl | awk '{ printf "ds%1s %s\n", $1, $2 }' | grep -w ds$dsX | awk -F',' '{print $3}');
        shift 2;
        ;;
    --best|-b)
        bestN="$2";
        shift 2;
        ;;      
    --first-generation|--first-gen|-fg)
        first_gen="$2";
        shift 2;
        ;;
    --last-generation|--last-gen|-lg)
        last_gen="$2";
        shift 2;
        ;;
    --best|-b)
        bestN="$2";
        shift 2;
        ;;
    *) 
        # ignore any other arguments
        shift;
    ;;
    esac
done
#
ds="DS${dsX}_${size}";
#
avgBestNFile="$plots/avg${ds}_best${bestN}.tsv";
bestNavgOutputPlot="$plots/avg${ds}_best${bestN}.pdf";
#
# get average stats
for gen in $(seq $first_gen $last_gen); do 
    awk -v gen=$gen -v bestN=$bestN -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=$4} END {print sum/bestN}' "../res$gen/$ds.tsv"; 
done > $avgBestNFile;
#
varBestNFile="$plots/var${ds}_best${bestN}.tsv";
bestNvarOutputPlot="$plots/var${ds}_best${bestN}.pdf";
#
# get variance stats
for gen in $(seq $first_gen $last_gen); do 
    avg=$(awk -v gen=$gen -F'\t' 'NR == gen+1 {print $1}' $avgBestNFile);
    #
    # var=sum(xi-X)/(n-1) for samples, but var=sum(xi-X)/N for whole population
    if [ $bestN -ne $POPULATION ]; then denominator=$(($bestN-1)); else denominator=$POPULATION; fi
    awk -v gen=$gen -v bestN=$bestN -v avg=$avg -v d=$denominator -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=($4-avg)^2} END {print sum/d}' "../res$gen/$ds.tsv"; 
done > $varBestNFile;
#
# plot average
gnuplot << EOF
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNavgOutputPlot"
    plot "$avgBestNFile"
    plot "$avgBestNFile" with lines
EOF
#
# plot variance
gnuplot << EOF
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNvarOutputPlot"
    plot "$varBestNFile"
    plot "$varBestNFile" with lines
EOF