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
gaArr=("e0_ga1_lr0_cmga")
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
    -e|--experiment|--experiment-number)
        experiment="e$(echo "$2" | tr -d "eE")";
        experiments+=( "$experiment" )
        shift 2; 
        ;;
    --dataset|-ds)
        dsx="DS$(echo "$2" | tr -d "dsDS")";
        size=$(awk '/'$dsx'[[:space:]]/{print $NF}' $ds_sizesBase2);
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
    -ymin)
        bps_min="$2";
        shift 2;
        ;;
    -ymax)
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
#
[ "${#experiments[@]}" -eq 1 ] && plotsFolder="$dsFolder/cmp_plots_$experiment" || statsFolder="$dsFolder/cmp_plots"
mkdir -p $plotsFolder;
#
sequenceName=$(awk '/'$dsx'/{print $2}' "$ds_sizesBase2" | tr '_' ' ');
#
# list of choosen GAs
gaArr+=( $(ls "$dsFolder" | grep -E "^($experiment)") )
for ga in "${gaArr[@]}"; do
    plotGAs+="'$dsFolder/$ga/stats/bps_avg_all.tsv' with lines title '$ga', "
done
#
# plot bps average, bestN bps results, cumsum ctime avg (all and best)
bps_avg="$plotsFolder/avgAllBPS.pdf";
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
    #
    plot $plotGAs
EOF
