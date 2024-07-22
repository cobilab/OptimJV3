#!/usr/bin/env bash
#
# default variables
bestN=50;
first_gen=1;
dsx="DS1";
ga="ga";
#
timeFormats=("s" "m" "h");
#
histInterval=0.1
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
# === FUNCTIONS ===========================================================================
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
# === PARSING ===========================================================================
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --genetic-algorithm|--algorithm|--ga|-ga|-a)
        ga="$2";
        shift 2; 
        ;;
    --dataset|-ds)
        dsx="DS$(echo "$2" | tr -d "dsDS")";
        size=$(awk '/'$dsx'[[:space:]]/{print $NF}' $ds_sizesBase2);
        shift 2;
        ;;
    --sequence|--seq|-s)
        sequence="$2";
        FIX_SEQUENCE_NAME "$sequence";
        dsx=$(awk '/'$sequence'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
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
    --hist-interval|-hi)
        histInterval="$2"
        shift 2
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
dsFolder="../${dsx}";
gaFolder="$dsFolder/$(ls $dsFolder | grep $ga)";
statsFolder="$gaFolder/stats";
plotsFolder="$gaFolder/plots";
mkdir -p $statsFolder $plotsFolder;
#
if [ -z "$last_gen" ]; then
    last_gen=$(ls $gaFolder/g*.tsv | wc -l);
fi
#
# gets population size by counting num of non-empty lines and excluding header
POPULATION_SIZE=$(( $(cat $gaFolder/g1.tsv | sed '/^\s*#/d;/^\s*$/d' | wc -l) - 2 ));
#
# === STATS ===========================================================================
#
# get bestN results from each generation (bps)
bestNFile="$statsFolder/bps_best${bestN}.tsv";
( for gen in $(seq $first_gen $last_gen); do 
    awk -F'\t' -v gen=$gen -v bestN=$bestN 'NR>2 && NR<=2+bestN {print gen"\t"$4}' "$gaFolder/g$gen.tsv"; 
done ) | sort -n -k1 -k2 | uniq > $bestNFile;
#
# get best1 result from each generation (bps)
best1File="$statsFolder/bps_best1.tsv";
( for gen in $(seq $first_gen $last_gen); do 
    awk -F'\t' -v gen=$gen 'NR==3 {print gen"\t"$4}' "$gaFolder/g$gen.tsv"; 
done ) > $best1File;
#
# get average stats (bps) (all)
avgBPSallFile="$statsFolder/bps_avg_all.tsv";
for gen in $(seq $first_gen $last_gen); do 
    awk -v gen=$gen -v p=$POPULATION_SIZE -F'\t' 'NR >= 3 {sum+=$4} END {print gen"\t"sum/p}' "$gaFolder/g$gen.tsv"; 
done > $avgBPSallFile;
#
# get average stats (bps) (bestN)
avgBestNFile="$statsFolder/bps_avg_best${bestN}.tsv";
for gen in $(seq $first_gen $last_gen); do 
    awk -v gen=$gen -v bestN=$bestN -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=$4} END {print gen"\t"sum/bestN}' "$gaFolder/g$gen.tsv"; 
done > $avgBestNFile;
#
# get variance stats (bps) (bestN) 
varBestNFile="$statsFolder/bps_var_best${bestN}.tsv";
for gen in $(seq $first_gen $last_gen); do 
    avg=$(awk -F'\t' 'NR == gen+1 {print $1}' $avgBestNFile);
    #
    # var equals sum(xi-X)/(n-1) for samples, but var equals sum(xi-X)/N for whole population
    if [ $bestN -ne $POPULATION_SIZE ]; then denominator=$(($bestN-1)); else denominator=$POPULATION_SIZE; fi
    awk -v gen=$gen -v bestN=$bestN -v avg=$avg -v d=$denominator -F'\t' 'NR >= 3 && NR <= 2+bestN {sum+=($4-avg)^2} END {print gen"\t"sum/d}' "$gaFolder/g$gen.tsv"; 
done > $varBestNFile;
#
for timeFormat in ${timeFormats[@]}; do
    #
    # get time denominator
    if [ "$timeFormat" = "s" ]; then
        timeDenominator=1;
    elif [ "$timeFormat" = "m" ]; then
        timeDenominator=60;
    elif [ "$timeFormat" = "h" ]; then
        timeDenominator=3600;
    fi
    #
    # get average stats (c_time) (all)
    avgAllFile_ctime="$statsFolder/ctime_avg_all_$timeFormat.tsv";
    for gen in $(seq $first_gen $last_gen); do 
        awk -F'\t' -v gen=$gen -v p=$POPULATION_SIZE -v d=$timeDenominator 'NR >= 3 {sum+=$5/d} END {print gen"\t"sum/p}' "$gaFolder/g$gen.tsv"; 
    done > $avgAllFile_ctime;
    #
    # get average stats (c_time) (bestN)
    avgBestNFile_ctime="$statsFolder/ctime_avg_best${bestN}_$timeFormat.tsv";
    for gen in $(seq $first_gen $last_gen); do 
        awk -F'\t' -v gen=$gen -v bestN=$bestN -v d=$timeDenominator 'NR >= 3 && NR <= 2+bestN {sum+=$5/d} END {print gen"\t"sum/bestN}' "$gaFolder/g$gen.tsv"; 
    done > $avgBestNFile_ctime;
    #
    # get cumsum average stats (cc_time) (all)
    avgAllFile_cctime="$statsFolder/cctime_avg_all_$timeFormat.tsv";
    awk -v gen=$first_gen -F'\t' '{csum+=$2; print gen"\t"csum; gen+=1}' "$avgAllFile_ctime" > $avgAllFile_cctime;
    #
    # get cumsum average stats (cc_time) (bestN)
    avgBestNFile_cctime="$statsFolder/cctime_avg_best${bestN}_$timeFormat.tsv";
    awk -v gen=$first_gen -F'\t' '{csum+=$2; print gen"\t"csum; gen+=1}' "$avgBestNFile_ctime" > $avgBestNFile_cctime;
done
#
# bps histogram
allSortedRes_bps="$gaFolder/allSortedRes_bps_ctime_s.tsv";
allBPS="$statsFolder/bps_absFreq.tsv";
awk -F'\t' -v lg=$last_gen 'NR>2 && $(NF-1)<=lg {print $4}' $allSortedRes_bps | uniq -c | awk '{print $2"\t"$1}' > $allBPS;
#
minBPS=$(awk 'NR==1 {print $1}' $allBPS)
histBPS="$statsFolder/bps_hist_abs.tsv";
awk -v m=$minBPS -v i=$histInterval '{ if ($1-m < i) sum+=$2; else { print m"\t"sum; m=$1; sum=$2 } } END {print m"\t"sum}' $allBPS > $histBPS
#
histBPSrel="$statsFolder/bps_hist_rel.tsv"
sum=$(awk '{ sum+=$2 } END { print sum }' $histBPS)
awk -v s=$sum '{printf "%.3f\t%.3f\n", $1, $2/s}' $histBPS > $histBPSrel
#
sequenceName=$(awk '/'$dsx'/{print $2}' "$ds_sizesBase2" | tr '_' ' ');
#
# === PLOTS ===========================================================================
#
for timeFormat in ${timeFormats[@]}; do
#
avgAllFile_ctime="$statsFolder/ctime_avg_all_$timeFormat.tsv";
avgBestNFile_ctime="$statsFolder/ctime_avg_best${bestN}_$timeFormat.tsv";
avgAllFile_cctime="$statsFolder/cctime_avg_all_$timeFormat.tsv";
avgBestNFile_cctime="$statsFolder/cctime_avg_best${bestN}_$timeFormat.tsv";
#
# plot bps average, bestN bps results, ctime avg (all and best)
avgAndDotsAllAndBestNOutputPlot_bps_ctime="$plotsFolder/bps_b${bestN}_ctime_${timeFormat}_fg${first_gen}_lg${last_gen}.pdf";
gnuplot << EOF
    #set title "Average bPS with $bestN most optimal bPS values of $sequenceName"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set key outside top horizontal Right noreverse noenhanced autotitle nobox
    #set key bottom right
    #
    # set up the axis on the left side for bps
    set ylabel "bPS"
    set ytics nomirror
    #
    # set up the axis on the right side for C time
    set y2label "C TIME ($timeFormat)"
    set y2tics nomirror
    #
    # set up the axis below for generation
    set xlabel "Generation"
    set xtics nomirror
    set xrange [$first_gen:$last_gen]
    #
    set style line 6 lc rgb '#990000'  pt 6 ps 0.6  # circle
    #
    set output "$avgAndDotsAllAndBestNOutputPlot_bps_ctime"
    plot "$bestNFile" title "$bestN best bps", \
    "$avgBPSallFile" with lines title "avg bps (all)", \
    "$avgBestNFile" with lines title "avg bps (best $bestN)", \
    "$best1File" with lines title "best bps", \
    "$avgAllFile_ctime" with lines axes x1y2 title "avg c time (all)", \
    "$avgBestNFile_ctime" with lines axes x1y2 title "avg c time (best $bestN)"
    set key bottom right
    
EOF
#
# plot bps average, bestN bps results, cumsum ctime avg (all and best)
avgAndDotsBestNOutputPlot_bps_cctime="$plotsFolder/bps_b${bestN}_cctime_${timeFormat}_fg${first_gen}_lg${last_gen}.pdf";
gnuplot << EOF
    #set title "$sequenceName - Avg bPS and cumulative sum of avg CTIME"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set key outside top horizontal Right noreverse noenhanced autotitle nobox
    #set key bottom right
    #
    # set up the axis on the left side for bps
    set ylabel "bPS"
    set ytics nomirror
    #
    # set up the axis on the right side for C time
    set y2label "C TIME ($timeFormat)"
    set y2tics nomirror
    #
    # set up the axis below for generation
    set xlabel "Generation"
    set xtics nomirror
    set xrange [$first_gen:$last_gen]
    #
    set output "$avgAndDotsBestNOutputPlot_bps_cctime"
    plot "$bestNFile" title "$bestN best bps", \
    "$avgBPSallFile" with lines title "avg bps (all)", \
    "$avgBestNFile" with lines title "avg bps (best $bestN)", \
    "$best1File" with lines title "best bps", \
    "$avgAllFile_cctime" with lines axes x1y2 title "csum avg c time (all)", \
    "$avgBestNFile_cctime" with lines axes x1y2 title "csum avg c time (best $bestN)" 
    
EOF
#
done
#
# plot bps average (all and best)
bestNavgOutputPlot="$plotsFolder/bps_b${bestN}_fg${first_gen}_lg${last_gen}.pdf";
gnuplot << EOF
    set title "$sequenceName - Average BPS (best $bestN)"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNavgOutputPlot"
    plot "$avgBPSallFile" with lines title "avg bps (all)", \
    "$avgBestNFile" with lines title "avg bps (best $bestN)"
EOF
#
# plot bps variance
bestNvarOutputPlot="$plotsFolder/var_bps_b${bestN}_fg${first_gen}_lg${last_gen}.pdf";
gnuplot << EOF
    set title "$sequenceName - BPS variance (best $bestN)"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$bestNvarOutputPlot"
    plot "$varBestNFile" with lines title "var bPS (best $bestN)"
EOF
#
histBPSpdf="$plotsFolder/hist_abs_bps.pdf";
gnuplot << EOF
    set title "Absolute frequency of bPS with interval = $histInterval"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set style histogram rows
    set boxwidth 0.8
    set key outside top horizontal Right noreverse noenhanced autotitle nobox
    #
    # Set up the axis on the left side for bps
    set ylabel "Absolute Frequency"
    set ytics nomirror
    #
    # set up the axis below for generation
    set xlabel "bPS"
    set xtics nomirror
    #
    # histogram style
    set style data histogram
    set boxwidth $histInterval absolute
    set style fill solid 0.5 border -1
    set grid y
    #
    set output "$histBPSpdf"
    plot "$histBPS" using 1:2 with boxes lc rgb "blue" notitle, "" u 1:2:2 with labels offset char 0,0.5 notitle
EOF
#
histBPSrelPdf="$plotsFolder/hist_rel_bps.pdf";
gnuplot << EOF
    set title "Relative frequency of bPS with interval = $histInterval"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set style histogram rows
    set boxwidth 0.8
    set key outside top horizontal Right noreverse noenhanced autotitle nobox
    #
    # Set up the axis on the left side for bps
    set ylabel "Relative Frequency"
    set ytics nomirror
    #
    # set up the axis below for generation
    set xlabel "bPS"
    set xtics nomirror
    #
    # "z axis" are the labels above the bars
    set ztics rotate by 45 offset -0.8,-1.8
    #
    # histogram style
    set style data histogram
    set boxwidth $histInterval absolute
    set style fill solid 0.5 border -1
    set grid y
    #
    set output "$histBPSrelPdf"
    plot "$histBPSrel" using 1:2 with boxes lc rgb "blue" notitle, "" u 1:2:2 with labels rotate by 0 offset char 0,0.5 notitle
EOF
