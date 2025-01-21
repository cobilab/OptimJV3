#!/usr/bin/env bash
#
# default variables
bestNpercentage=0.5;
first_gen=1;
dsx="DS1";
ga="ga";
#
bps_min="*"
bps_max="2.05"
timeFormats=("s" "m" "h");
tmin_s="0";
tmax_s="*";
tmin_m="0";
tmax_m="*";
tmin_h="0";
tmax_h="*";
#
histInterval=0.1
#
configJson="../config.json"
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
# === FUNCTIONS ===========================================================================
#
function SHOW_HELP() {
  echo " -------------------------------------------------------";
  echo "                                                        ";
  echo " OptimJV3 - optimize JARVIS3 CM and RM parameters       ";
  echo "                                                        ";
  echo " Program options ---------------------------------------";
  echo "                                                        ";
  echo "-h|--help......................................Show this";
  echo "-a|-ga|--genetic-algorithm...Define (folder) name of the";
  echo "                                       genetic algorithm";
  echo "-s|--seq|--sequence............Choose sequence name/file";
  echo "-ds|--dataset......Select sequence by its dataset number";
  echo "-pb|--percentage-best..........Define percentage of best";
  echo "                                     individuals to plot";
  echo "-b|--best......Define number of best individuals to plot";
  echo "-fg|--first-generation...Specify first generation number";
  echo "-lg|--last-generation......Select last generation number";
  echo "-br|--b-range..................Define x-axis (BPS range)";
  echo "-trs|--trange-s...Define y-axis (time range, in seconds)";
  echo "-trm|--trange-m...Define y-axis (time range, in minutes)";
  echo "-trh|--trange-h.....Define y-axis (time range, in hours)";
  echo "-hi|--hist-interval........Define bin size for histogram";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
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
    -h|--help)
        SHOW_HELP;
        exit;
        ;;
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
    --percentage-best|--best-percentage|-bp|-pb)
        bestNpercentage="$2";
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
    -br|--b-range)
        bps_min="$(echo $2 | cut -d':' -f1)";
        bps_max="$(echo $2 | cut -d':' -f2)";
        shift 2;
        ;;
    -trs|--trange-s)
        tmin_s="$(echo $2 | cut -d':' -f1)";
        tmax_s="$(echo $2 | cut -d':' -f2)";
        shift 2;
        ;;
    -trm|--trange-m)
        tmin_m="$(echo $2 | cut -d':' -f1)";
        tmax_m="$(echo $2 | cut -d':' -f2)";
        shift 2;
        ;;
    -trh|--trange-h)
        tmin_h="$(echo $2 | cut -d':' -f1)";
        tmax_h="$(echo $2 | cut -d':' -f2)";
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
gaFolder="$dsFolder/$(ls $dsFolder | grep $ga | head -n1)";
genFolder="$gaFolder/generations"
statsFolder="$gaFolder/stats";
plotsFolder="$gaFolder/plots";
mkdir -p $statsFolder $plotsFolder;
#
if [ -z "$last_gen" ]; then
    last_gen=$(ls $genFolder/g*.tsv | wc -l);
fi
#
# gets population size by counting num of non-empty lines and excluding header
POPULATION_SIZE=$(( $(cat $genFolder/g1.tsv | sed '/^\s*#/d;/^\s*$/d' | wc -l) - 2 ));
bestN=$(awk -v ps=$POPULATION_SIZE -v bp=$bestNpercentage 'BEGIN {r=sprintf("%.0f",bp*ps);print r}');
#
# === STATS ===========================================================================
#
# get bestN results from each generation (bps)
bestNFile="$statsFolder/bps_best${bestN}.tsv";
( for gen in $(seq $first_gen $last_gen); do 
    awk -F'\t' -v gen=$gen -v bestN=$bestN 'NR==2 {if ($3 ~ /DOMINANCE/) {col=6} else {col=5} } 
    NR>2 && NR<=2+bestN {if ($2==0) print gen"\t"$col}' "$genFolder/g$gen.tsv"; 
done ) | sort -n -k1 -k2 | uniq > $bestNFile;
#
# get best1 result from each generation (bps)
best1File="$statsFolder/bps_best1.tsv";
( for gen in $(seq $first_gen $last_gen); do 
    awk -F'\t' -v gen=$gen 'NR==2 {if ($3 ~ /DOMINANCE/) {col=6} else {col=5} } 
    NR==3 {if ($2==0) print gen"\t"$col}' "$genFolder/g$gen.tsv"; 
done ) > $best1File;
#
# get average stats (bps) (all)
avgBPSallFile="$statsFolder/bps_avg_all.tsv";
for gen in $(seq $first_gen $last_gen); do 
    awk -v gen=$gen -v p=$POPULATION_SIZE -F'\t' 'NR==2 {if ($3 ~ /DOMINANCE/) {col=6} else {col=5} } 
    NR >= 3 {if ($2==0) sum+=$col; else sum+=2} END {print gen"\t"sum/p}' "$genFolder/g$gen.tsv"; 
done > $avgBPSallFile;
#
# get average stats (bps) (bestN)
avgBestNFile="$statsFolder/bps_avg_best${bestN}.tsv";
for gen in $(seq $first_gen $last_gen); do 
    awk -v gen=$gen -v bestN=$bestN -F'\t' 'NR==2 {if ($3 ~ /DOMINANCE/) {col=6} else {col=5} } 
    NR >= 3 && NR <= 2+bestN {if ($2==0) sum+=$col; else sum+=2} END {print gen"\t"sum/bestN}' "$genFolder/g$gen.tsv"; 
done > $avgBestNFile;
#
# get variance stats (bps) (bestN) 
varBestNFile="$statsFolder/bps_var_best${bestN}.tsv";
for gen in $(seq $first_gen $last_gen); do 
    avg=$(awk -F'\t' 'NR == gen+1 {print $1}' $avgBestNFile);
    #
    # var equals sum(xi-X)/(n-1) for samples, but var equals sum(xi-X)/N for whole population
    if [ $bestN -ne $POPULATION_SIZE ]; then denominator=$(($bestN-1)); else denominator=$POPULATION_SIZE; fi
    awk -v gen=$gen -v bestN=$bestN -v avg=$avg -v d=$denominator -F'\t' 'NR==2 {if ($3 ~ /DOMINANCE/) {col=6} else {col=5} } 
    NR >= 3 && NR <= 2+bestN {if ($2==0) sum+=($col-avg)^2; else sum+=(2-avg)^2} END {print gen"\t"sum/d}' "$genFolder/g$gen.tsv"; 
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
        awk -F'\t' -v gen=$gen -v p=$POPULATION_SIZE -v d=$timeDenominator 'NR >= 3 {sum+=$6/d} END {print gen"\t"sum/p}' "$genFolder/g$gen.tsv"; 
    done > $avgAllFile_ctime;
    #
    # get average stats (c_time) (bestN)
    avgBestNFile_ctime="$statsFolder/ctime_avg_best${bestN}_$timeFormat.tsv";
    for gen in $(seq $first_gen $last_gen); do 
        awk -F'\t' -v gen=$gen -v bestN=$bestN -v d=$timeDenominator 'NR >= 3 && NR <= 2+bestN {sum+=$6/d} END {print gen"\t"sum/bestN}' "$genFolder/g$gen.tsv"; 
    done > $avgBestNFile_ctime;
    #
    # get cumulative sum of compression time (this gives the time the software took to run until that generation)
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
allSortedRes_bps="$gaFolder/eval/allSortedRes_bps.tsv";
allBPS="$statsFolder/bps_absFreq.tsv";
awk -F'\t' -v lg=$last_gen 'NR>2 && $(NF-1)<=lg {if ($2==0) print $5; else print 2}' $allSortedRes_bps | uniq -c | awk '{print $2"\t"$1}' > $allBPS;
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
if [ "$timeFormat" = "s" ]; then
    tmin=$tmin_s;
    tmax=$tmax_s;
elif [ "$timeFormat" = "m" ]; then
    tmin=$tmin_m;
    tmax=$tmax_m;
elif [ "$timeFormat" = "h" ]; then
    tmin=$tmin_h;
    tmax=$tmax_h;
fi
#
avgAllFile_ctime="$statsFolder/ctime_avg_all_$timeFormat.tsv";
avgBestNFile_ctime="$statsFolder/ctime_avg_best${bestN}_$timeFormat.tsv";
avgAllFile_cctime="$statsFolder/cctime_avg_all_$timeFormat.tsv";
avgBestNFile_cctime="$statsFolder/cctime_avg_best${bestN}_$timeFormat.tsv";
#
# plot bps average, bestN bps results, ctime avg (all and best),
# plot bps average, bestN bps results, cumsum ctime avg (all and best)
avgAllAndBestNOutputPlot_bps_ctime="$plotsFolder/bps_b${bestN}_ctime_${timeFormat}_fg${first_gen}_lg${last_gen}.pdf";
avgBestNOutputPlot_bps_cctime="$plotsFolder/bps_b${bestN}_cctime_${timeFormat}_fg${first_gen}_lg${last_gen}.pdf";
#
gnuplot << EOF
    #set title "$sequenceName"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set key outside top horizontal Right noreverse noenhanced autotitle nobox
    #set key bottom right
    #
    set grid
    set grid xtics ytics
    #
    # set up the axis on the left side for bps
    set ylabel "bPS"
    set ytics nomirror
    set yrange [$bps_min:$bps_max]
    #
    # set up the axis on the right side for C time
    set y2label "C TIME ($timeFormat)"
    set y2range [$tmin:$tmax]
    set y2tics nomirror
    #
    # set up the axis below for generation
    set xlabel "Generation"
    set xtics nomirror
    set xrange [$first_gen:$last_gen]
    #
    # line styles
    set style line 1 lc rgb '#990099' pt 1 ps 0.1 # N best bps; dots
    set style line 2 lt 1 lc rgb '#004C99' ps 1 # avg bps (all)
    set style line 3 lt 1 lc rgb '#990099' ps 1 # avg bps (best N)
    set style line 4 lt 1 lc rgb '#CC0000' ps 1 # best bps
    set style line 5 lt 1 lc rgb '#009900' ps 1 dashtype '_-' # csum avg c time (all)
    set style line 6 lt 1 lc rgb '#990000' ps 1 dashtype '_-' # csum avg c time (best N)
    #
    list="$avgAllAndBestNOutputPlot_bps_ctime $avgBestNOutputPlot_bps_cctime"
    do for [elem in list] {
        set output elem
        #
        print elem
        avgAllFile = (strstrt(elem, "_ctime") > 0) ? "$avgAllFile_ctime" : "$avgAllFile_cctime"
        avgBestNFile = (strstrt(elem, "_ctime") > 0) ? "$avgBestNFile_ctime" : "$avgBestNFile_cctime"
        #
        # show dots representing the N best results if first_gen=1 and last_gen-first_gen<=20
        if ($first_gen==1) & ($last_gen-$first_gen<=20) {
            plot "$bestNFile" linestyle 1 title "$bestN best bps", \
            "$avgBPSallFile" with lines linestyle 2 title "avg bps (all)", \
            "$avgBestNFile" with lines linestyle 3 title "avg bps (best $bestN)", \
            "$best1File" with lines linestyle 4 title "best bps", \
            avgAllFile with lines linestyle 5 axes x1y2 title "csum avg c time (all)", \
            avgBestNFile with lines linestyle 6 axes x1y2 title "csum avg c time (best $bestN)";
        } else {
            plot "$avgBPSallFile" with lines linestyle 2 title "avg bps (all)", \
            "$avgBestNFile" with lines linestyle 3 title "avg bps (best $bestN)", \
            "$best1File" with lines linestyle 4 title "best bps", \
            avgAllFile with lines linestyle 5 axes x1y2 title "csum avg c time (all)", \
            avgBestNFile with lines linestyle 6 axes x1y2 title "csum avg c time (best $bestN)";
        }
    }
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
histBPSpdf="$plotsFolder/hist_abs_bps_lg${last_gen}.pdf";
gnuplot << EOF
    set title "$sequenceName"
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
histBPSrelPdf="$plotsFolder/hist_rel_bps_lg${last_gen}.pdf";
gnuplot << EOF
    set title "$sequenceName"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set style histogram rows
    set boxwidth 0.8
    set key outside top horizontal Right noreverse noenhanced autotitle nobox
    #
    # Set up the axis on the left side for bps
    set ylabel "Relative Frequency"
    set ytics nomirror
    set yrange [0:1.05]  # Extend the upper limit by 10%
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
    plot "$histBPSrel" using 1:2 with boxes lc rgb "blue" notitle, "" u 1:2:2 with labels rotate by 75 offset char 0,1.5 notitle
EOF
