#!/bin/bash
#
#!/usr/bin/env bash
#
# default variables
bestN=50;
first_gen=1;
dsx="DS1";
ga="ga";
#
interval=0.1
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
        shift 2;
        ;;
    --sequence|--seq|-s)
        sequence="$2";
        ds=$(awk '/'$sequence'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
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
    --interval)
        interval="$2"
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
allSortedRes_bps="$gaFolder/allSortedRes_bps_ctime_s.tsv";
allBPS="$statsFolder/allBPS.tsv";
awk 'NR>2 {print $4}' $allSortedRes_bps | uniq -c | awk '{print $2"\t"$1}' > $allBPS;
#
minBPS=$(awk 'NR==1 {print $1}' $allBPS)
histBPS="$statsFolder/histBPS.tsv";
awk -v m=$minBPS -v i=$interval '{ if ($1-m < i) sum+=$2; else { print m"\t"sum; m=$1; sum=$2 } } END {print m"\t"sum}' $allBPS > $histBPS
#
histBPSrel="$statsFolder/histBPSrel.tsv"
sum=$(awk '{ sum+=$2 } END { print sum }' $histBPS)
awk -v s=$sum '{printf "%.3f\t%.3f\n", $1, $2/s}' $histBPS > $histBPSrel
#
# === HISTOGRAM ===========================================================================
#
histBPSpdf="$plotsFolder/histBPS.pdf";
gnuplot << EOF
    set title "Absolute frequency of bPS with interval = $interval"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set style histogram rows
    set boxwidth 0.8
    #set key outside right top vertical Right noreverse noenhanced autotitle nobox
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
    set boxwidth $interval absolute
    set style fill solid 0.5 border -1
    set grid y
    #
    set output "$histBPSpdf"
    plot "$histBPS" using 1:2 with boxes lc rgb "blue" notitle, "" u 1:2:2 with labels offset char 0,0.5 notitle
EOF
#
histBPSrelPdf="$plotsFolder/histBPSrel.pdf";
gnuplot << EOF
    set title "Relative frequency of bPS with interval = $interval"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set style histogram rows
    set boxwidth 0.8
    #set key outside right top vertical Right noreverse noenhanced autotitle nobox
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
    set boxwidth $interval absolute
    set style fill solid 0.5 border -1
    set grid y
    #
    set output "$histBPSrelPdf"
    plot "$histBPSrel" using 1:2 with boxes lc rgb "blue" notitle, "" u 1:2:2 with labels rotate by 0 offset char 0,0.5 notitle
EOF
