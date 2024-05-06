#!/usr/bin/env bash
#
# default variables
POPULATION=100;
bestN=10;
first_gen=0;
last_gen=300;
sizes=("xs" "s" "m" "l" "xl");
dsx="DS1";
size="xs";
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
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
# ==============================================================================
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --dataset|-ds)
        dsx="DS$(echo "$2" | tr -d "dsDS")";
        size=$(awk '/'$dsx'[[:space:]]/{print $NF}' $ds_sizesBase2);
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
dsFolder="../${dsx}";
statsFolder="$dsFolder/stats";
plotsFolder="$dsFolder/plots";
mkdir -p $statsFolder $plotsFolder;
#
# get bestN results from each generation
bestNFile="$statsFolder/best${bestN}.tsv";
avgAndBestNOutputPlot="$plotsFolder/avgAndBest${bestN}.pdf";
#
awk -F'\t' 'NR >= 3 {print $(NF-1)"\t"$4}' "$dsFolder/g${last_gen}_body.tsv" > $bestNFile;
sort -u $bestNFile -o $bestNFile;
#
# get average stats
avgBestNFile="$statsFolder/avg_best${bestN}.tsv";
bestNavgOutputPlot="$plotsFolder/avg_best${bestN}.pdf";
#
for gen in $(seq $first_gen $last_gen); do 
    awk -v bestN=$bestN -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=$4} END {print sum/bestN}' "$dsFolder/g$gen.tsv"; 
done > $avgBestNFile;
#
# get variance stats
varBestNFile="$statsFolder/var_best${bestN}.tsv";
bestNvarOutputPlot="$plotsFolder/var_best${bestN}.pdf";
#
for gen in $(seq $first_gen $last_gen); do 
    avg=$(awk -F'\t' 'NR == gen+1 {print $1}' $avgBestNFile);
    #
    # var equals sum(xi-X)/(n-1) for samples, but var equals sum(xi-X)/N for whole population
    if [ $bestN -ne $POPULATION ]; then denominator=$(($bestN-1)); else denominator=$POPULATION; fi
    awk -v bestN=$bestN -v avg=$avg -v d=$denominator -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=($4-avg)^2} END {print sum/d}' "$dsFolder/g$gen.tsv"; 
done > $varBestNFile;
#
# plot average and bestN results
gnuplot << EOF
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$avgAndBestNOutputPlot"
    set xrange [0:300]
    plot "$bestNFile", "$avgBestNFile" with lines
EOF
#
# plot average
gnuplot << EOF
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNavgOutputPlot"
    plot "$avgBestNFile" with lines
EOF
#
# plot variance
gnuplot << EOF
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNvarOutputPlot"
    plot "$varBestNFile" with lines
EOF
