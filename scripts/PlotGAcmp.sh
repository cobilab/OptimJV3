#!/usr/bin/env bash
#
# default variables
bestN=50;
fg=1;
dsx="DS10";
ga1="ga1";
ga2="ga2";
#
timeFormats=("s" "m" "h");
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
    --genetic-algorithm1|--algorithm1|--ga1|-ga1|-a1)
        ga1="$2";
        shift 2; 
        ;;
    --genetic-algorithm2|--algorithm2|--ga2|-ga2|-a2)
        ga2="$2";
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
        fg="$2";
        shift 2;
        ;;
    --last-generation|--last-gen|-lg)
        lg="$2";
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
dsFolder="../${dsx}";
ga1Folder="$dsFolder/$(ls $dsFolder | grep $ga1)";
ga2Folder="$dsFolder/$(ls $dsFolder | grep $ga2)";
#
if [ -z "$lg" ]; then
    lg_ga1=$(ls $ga1Folder/g*.tsv | wc -l);
    lg_ga2=$(ls $ga2Folder/g*.tsv | wc -l);
    lg=$(( $lg_ga1 > $lg_ga2 ? $lg_ga1 : $lg_ga2 ));
fi
#
statsFolder="$dsFolder/cmp_stats";
plotsFolder="$dsFolder/cmp_plots";
mkdir -p $statsFolder $plotsFolder;
#
statsFolder="$statsFolder/${ga1}_minus_${ga2}";
plotsFolder="$plotsFolder/${ga1}_minus_${ga2}";
mkdir -p $statsFolder $plotsFolder;
#
# get average stats diff (bps) (all)
avgAllFile="$statsFolder/bps_avg_all.tsv";
paste $ga1Folder/stats/bps_avg_all.tsv $ga2Folder/stats/bps_avg_all.tsv | awk -v gen=$fg '{print gen"\t"$2-$4; gen+=1}' > $avgAllFile;
#
# get average stats diff (bps) (bestN)
avgBestNFile="$statsFolder/bps_avg_best${bestN}.tsv";
paste $ga1Folder/stats/bps_avg_best${bestN}.tsv $ga2Folder/stats/bps_avg_best${bestN}.tsv | awk -v gen=$fg '{print gen"\t"$2-$4; gen+=1}' > $avgBestNFile;
#
# get variance stats diff (bps)
varBestNFile="$statsFolder/bps_var_best${bestN}.tsv";
paste $ga1Folder/stats/bps_var_best${bestN}.tsv $ga2Folder/stats/bps_var_best${bestN}.tsv | awk -v gen=$fg '{print gen"\t"$2-$4; gen+=1}' > $varBestNFile;
#
for tf in ${timeFormats[@]}; do
    #
    # get cumsum average stats diff (c_time) (all)
    avgAllFile_cctime="$statsFolder/cctime_avg_all_$tf.tsv";
    paste $ga1Folder/stats/cctime_avg_all_$tf.tsv $ga2Folder/stats/cctime_avg_all_$tf.tsv | awk -v gen=$fg '{print gen"\t"$2-$4; gen+=1}' > $avgAllFile_cctime;
    #
    # get cumsum average stats diff (c_time) (bestN)
    avgBestNFile_cctime="$statsFolder/cctime_avg_best${bestN}_$tf.tsv";
    paste $ga1Folder/stats/cctime_avg_best${bestN}_$tf.tsv $ga2Folder/stats/cctime_avg_best${bestN}_$tf.tsv | awk -v gen=$fg '{print gen"\t"$2-$4; gen+=1}' > $avgBestNFile_cctime;
done
#
sequenceName=$(awk '/'$dsx'/{print $2}' "$ds_sizesBase2" | tr '_' ' ');
#
for tf in ${timeFormats[@]}; do
#
# plot bps average, bestN bps results, cumsum ctime avg (all and best)
avgAndDotsBestNOutputPlot_bps_cctime="$plotsFolder/bps_b${bestN}_cctime_$tf_fg${fg}_lg${lg}.pdf";
cat $avgAndDotsBestNOutputPlot_bps_cctime
gnuplot << EOF
    # set title "Difference between ${ga1//_/} and ${ga2//_/} for sequence $sequenceName"
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
    # set y2range [0:300]
    #
    # set up the axis below for generation
    set xlabel "Generation"
    set xtics nomirror
    set xrange [$fg:$lg]
    #
    set output "$avgAndDotsBestNOutputPlot_bps_cctime"
    plot "$avgAllFile" with lines title "avg bps (all)", \
    "$avgBestNFile" with lines title "avg bps (best $bestN)", \
    "$avgAllFile_cctime" with lines axes x1y2 title "csum avg c time (all)", \
    "$avgBestNFile_cctime" with lines axes x1y2 title "csum avg c time (best $bestN)"
EOF
#
# plot bps average (all and best)
bestNavgOutputPlot="$plotsFolder/bps_b${bestN}_fg${fg}_lg${lg}.pdf";
gnuplot << EOF
    # set title "Difference between avg bPS values of ${ga1//_/} and ${ga2//_/} (best $bestN) for sequence $sequenceName"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNavgOutputPlot"
    plot "$avgAllFile" with lines title "avg bps (all)", \
    "$avgBestNFile" with lines title "avg bps (best $bestN)",
EOF
#
# plot bps variance
bestNvarOutputPlot="$plotsFolder/var_bps_b${bestN}_fg${fg}_lg${lg}.pdf";
gnuplot << EOF
    # set title "Difference between var bPS values of ${ga1//_/} and ${ga2//_/} (best $bestN) for sequence $sequenceName
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNvarOutputPlot"
    plot "$varBestNFile" with lines
EOF
#
done
