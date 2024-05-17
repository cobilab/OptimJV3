#!/usr/bin/env bash
#
# default variables
POPULATION=100;
bestN=90;
first_gen=0;
last_gen=300;
dsx="DS10";
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
model1="model";
model2="model";
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
    --model-folder1|--model1|-m1)
        model1="$2";
        shift 2; 
        ;;
    --model-folder2|--model2|-m2)
        model2="$2";
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
dsFolder="../${dsx}";
statsFolder="$dsFolder/cmp_stats";
plotsFolder="$dsFolder/cmp_plots";
mkdir -p $statsFolder $plotsFolder;
#
# get average stats diff (bps)
avgBestNFile="$statsFolder/avg_best${bestN}.tsv";
paste $dsFolder/$model1/stats/avg_best${bestN}.tsv $dsFolder/$model2/stats/avg_best${bestN}.tsv | awk '{print $2-$1}' > $avgBestNFile;
#
# get cumsum average stats diff (c_time)
avgBestNFile_cctime="$statsFolder/avg_best${bestN}_cctime.tsv";
paste $dsFolder/$model1/stats/avg_best${bestN}_cctime.tsv $dsFolder/$model2/stats/avg_best${bestN}_cctime.tsv | awk '{print $2-$1}' > $avgBestNFile_cctime;
#
# get variance stats diff (bps)
varBestNFile="$statsFolder/var_best${bestN}.tsv";
paste $dsFolder/$model1/stats/var_best${bestN}.tsv $dsFolder/$model2/stats/var_best${bestN}.tsv | awk '{print $2-$1}' > $varBestNFile;
#
sequenceName=$(awk '/'$dsx'/{print $2}' "$ds_sizesBase2" | tr '_' ' ');
#
# plot bps average, bestN bps results, cumsum ctime avg
avgAndDotsBestNOutputPlot_bps_cctime="$plotsFolder/avgAndDots_best${bestN}_bps_cctime.pdf";
gnuplot << EOF
    set title "Average bPS with $bestN most optimal bPS values of $sequenceName (diff)"
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
    plot "$avgBestNFile" with lines title "avg bps (diff)", \
    "$avgBestNFile_cctime" with lines axes x1y2 title "csum avg c time (diff)"
EOF
#
# plot bps average
bestNavgOutputPlot="$plotsFolder/avg_best${bestN}.pdf";
gnuplot << EOF
    set title "Average of $sequenceName for the $bestN most optimal bPS values (diff)"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNavgOutputPlot"
    plot "$avgBestNFile" with lines
EOF
#
# plot bps variance
bestNvarOutputPlot="$plotsFolder/var_best${bestN}.pdf";
gnuplot << EOF
    set title "Variance of $sequenceName for the $bestN most optimal bPS values (diff)"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNvarOutputPlot"
    plot "$varBestNFile" with lines
EOF
