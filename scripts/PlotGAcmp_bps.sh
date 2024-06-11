#!/usr/bin/env bash
#
# default variables
bestN=50;
first_gen=1;
bps_min=0;
bps_max=2;
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
        first_gen="$2";
        shift 2;
        ;;
    --last-generation|--last-gen|-lg)
        last_gen="$2";
        shift 2;
        ;;
    --min-bps|--bps-min|-ym|-my)
        bps_min="$2";
        shift 2;
        ;;
    --max-bps|--bps-max|-yM|-My)
        bps_max="$2";
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
if [ -z "$last_gen" ]; then
    last_gen_ga1=$(ls $ga1Folder/g*.tsv | wc -l);
    last_gen_ga2=$(ls $ga2Folder/g*.tsv | wc -l);
    last_gen=$(( $last_gen_ga1 > $last_gen_ga2 ? $last_gen_ga1 : $last_gen_ga2 ));
fi
#
statsFolder="$dsFolder/cmp_stats";
plotsFolder="$dsFolder/cmp_plots";
mkdir -p $statsFolder $plotsFolder;
#
statsFolder="$statsFolder/bps";
plotsFolder="$plotsFolder/bps";
mkdir -p $statsFolder $plotsFolder;
#
sequenceName=$(awk '/'$dsx'/{print $2}' "$ds_sizesBase2" | tr '_' ' ');
#
# plot bps average, bestN bps results, cumsum ctime avg (all and best)
bps_avg="$plotsFolder/bps_avg.pdf";
gnuplot << EOF
    set title "BPS average"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    #set key outside right top vertical Right noreverse noenhanced autotitle nobox
    #
    # Set up the axis on the left side for bps
    set ylabel "bPS"
    set ytics nomirror
    # set yrange [$bps_min:$bps_max]
    #
    # set up the axis below for generation
    set xlabel "Generation"
    set xtics nomirror
    set xrange [$first_gen:$last_gen]
    #
    set output "$bps_avg"
    plot "../$dsx/ga1_cga/stats/avg_bps_all.tsv" with lines title "GA1 - cga", \
    "../$dsx/ga3_cga_p20_ns6/stats/avg_bps_all.tsv" with lines title "GA3 - ps=20, ns=6"
    # "../$dsx/ga4_moga_wbps50/stats/avg_bps_all.tsv" with lines title "GA4 - moga wBPS=0.5", \
    # "../$dsx/ga5_moga_wbps75/stats/avg_bps_all.tsv" with lines title "GA5 - moga wBPS=0.75", \
    # "../$dsx/ga6_moga_wbps90/stats/avg_bps_all.tsv" with lines title "GA6 - moga wBPS=0.9"
EOF
