#!/usr/bin/env bash
#
# default variables
POPULATION=100;
bestN=90;
first_gen=0;
last_gen=300;
dsx="DS1";
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
model="model";
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
    --model-folder|--model|-m)
        model="$2";
        shift 2; 
        ;;
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
    *) 
        # ignore any other arguments
        shift;
    ;;
    esac
done
#
dsFolder="../${dsx}/$model";
statsFolder="$dsFolder/stats";
plotsFolder="$dsFolder/plots";
mkdir -p $statsFolder $plotsFolder;
#
# get bestN results from each generation (bps)
bestNFile="$statsFolder/best${bestN}.tsv";
( for gen in $(seq $first_gen $last_gen); do 
    awk -F'\t' -v gen=$gen -v bestN=$bestN 'NR>2 && NR<=2+bestN {str+="$4\t";print gen"\t"$4}' "$dsFolder/g${gen}.tsv"; 
done ) | sort -n -k1 -k2 | uniq > $bestNFile;
#
# get average stats (bps)
avgBestNFile="$statsFolder/avg_best${bestN}.tsv";
for gen in $(seq $first_gen $last_gen); do 
    awk -v bestN=$bestN -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=$4} END {print sum/bestN}' "$dsFolder/g$gen.tsv"; 
done > $avgBestNFile;
#
# get average stats (c_time)
avgBestNFile_ctime="$statsFolder/avg_best${bestN}_ctime.tsv";
for gen in $(seq $first_gen $last_gen); do 
    awk -v bestN=$bestN -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=$5} END {print sum/bestN}' "$dsFolder/g$gen.tsv"; 
done > $avgBestNFile_ctime;
#
# get cumsum average stats (c_time)
avgBestNFile_cctime="$statsFolder/avg_best${bestN}_cctime.tsv";
awk -v bestN=$bestN -F'\t' '{csum+=$1; print csum}' "$avgBestNFile_ctime" > $avgBestNFile_cctime;
#
# get variance stats (bps)
varBestNFile="$statsFolder/var_best${bestN}.tsv";
for gen in $(seq $first_gen $last_gen); do 
    avg=$(awk -F'\t' 'NR == gen+1 {print $1}' $avgBestNFile);
    #
    # var equals sum(xi-X)/(n-1) for samples, but var equals sum(xi-X)/N for whole population
    if [ $bestN -ne $POPULATION ]; then denominator=$(($bestN-1)); else denominator=$POPULATION; fi
    awk -v bestN=$bestN -v avg=$avg -v d=$denominator -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=($4-avg)^2} END {print sum/d}' "$dsFolder/g$gen.tsv"; 
done > $varBestNFile;
#
sequenceName=$(awk '/'$dsx'/{print $2}' "$ds_sizesBase2" | tr '_' ' ');
#
# plot bps average, bestN bps results, ctime avg
avgAndDotsBestNOutputPlot_bps_ctime="$plotsFolder/avgAndDots_best${bestN}_bps_ctime.pdf";
gnuplot << EOF
    set title "Average bPS with $bestN most optimal bPS values of $sequenceName"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    #set key outside right top vertical Right noreverse noenhanced autotitle nobox
    #
    # Set up the axis on the left side for bps
    set ylabel "bPS"
    set ytics nomirror
    #
    # Set up the axis on the right side for C time
    set y2label "C TIME (s)"
    set y2tics nomirror
    #
    set output "$avgAndDotsBestNOutputPlot_bps_ctime"
    plot "$avgBestNFile" with lines title "avg bps", \
    "$bestNFile" title "$bestN best bps", \
    "$avgBestNFile_ctime" with lines axes x1y2 title "avg c time"
EOF
#
# plot bps average, bestN bps results, cumsum ctime avg
avgAndDotsBestNOutputPlot_bps_cctime="$plotsFolder/avgAndDots_best${bestN}_bps_cctime.pdf";
gnuplot << EOF
    set title "Average bPS with $bestN most optimal bPS values of $sequenceName"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    #set key outside right top vertical Right noreverse noenhanced autotitle nobox
    #
    # Set up the axis on the left side for bps
    set ylabel "bPS"
    set ytics nomirror
    #
    # Set up the axis on the right side for C time
    set y2label "C TIME (s)"
    set y2tics nomirror
    #
    set output "$avgAndDotsBestNOutputPlot_bps_cctime"
    plot "$avgBestNFile" with lines title "avg bps", \
    "$bestNFile" title "$bestN best bps", \
    "$avgBestNFile_cctime" with lines axes x1y2 title "csum avg c time"
EOF
#
# plot bps average
bestNavgOutputPlot="$plotsFolder/avg_best${bestN}.pdf";
gnuplot << EOF
    set title "Average of $sequenceName for the $bestN most optimal bPS values"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNavgOutputPlot"
    plot "$avgBestNFile" with lines
EOF
#
# plot bps variance
bestNvarOutputPlot="$plotsFolder/var_best${bestN}.pdf";
gnuplot << EOF
    set title "Variance of $sequenceName for the $bestN most optimal bPS values"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNvarOutputPlot"
    plot "$varBestNFile" with lines
EOF
