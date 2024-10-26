#!/usr/bin/env bash
#
# default variables
bestN=50;
first_gen=1;
dsx="DS10";
ga1="ga1";
ga2="ga2";
#
bps_min=0;
bps_max=2;
labelDetail="m"
tmin="0"
tmax="*"
#
configJson="../config.json"
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
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
function GET_LABEL() {
    case "$1" in
        "e0_ga1"*)
            label="CGA"
            ;;
        "e1_ga1"*)
            label="10% heuristic initialization"
            ;;
        "e1_ga2"*)
            label="25% heuristic initialization"
            ;;
        "e1_ga3"*)
            label="50% heuristic initialization"
            ;;
        "e1_ga4"*)
            label="75% heuristic initialization"
            ;;
        "e1_ga5"*)
            label="90% heuristic initialization"
            ;;
        "e1_ga6"*)
            label="Local search initialization"
            ;;
        "e2_ga1"*)
            label="Population size 20"
            ;;
        "e2_ga2"*)
            label="Population size 50"
            ;;
        "e2_ga3"*)
            label="Population size 80"
            ;;
        "e2_ga4"*)
            label="Population size 150"
            ;;
        "e3_ga1"*)
            label="MOGA (BPS weight = 0.1)"
            ;;
        "e3_ga2"*)
            label="MOGA (BPS weight = 0.25)"
            ;;
        "e3_ga3"*)
            label="MOGA (BPS weight = 0.5)"
            ;;
        "e3_ga4"*)
            label="MOGA (BPS weight = 0.75)"
            ;;
        "e3_ga5"*)
            label="MOGA (BPS weight = 0.9)"
            ;;
        "e4_ga1"*)
            label="Tournament Selection"
            ;;
        "e4_ga2_lr0_selRWS")
            label="Modified RWS"
            ;;
        "e5_ga1_lr0_mrc")
            label="Metameric Random Crossover"
            ;;
        *)
            echo "$1"
            ;;
    esac
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
statsArr=("bps_avg_all" "bps_best1" "cctime_avg_all_s" "cctime_avg_all_m" "cctime_avg_all_h")
#
for statsFile in "${statsArr[@]}"; do
    #
    # list of choosen GAs
    gaArr=( "e0_ga1_lr0_cmga" $(ls "$dsFolder" | grep -E "^($experiment)") )
    plotGAs=""
    for ga in "${gaArr[@]}"; do
        GET_LABEL "$ga"
        [[ "$ga" == "_continuation" ]] && continue
        plotGAs+="'$dsFolder/$ga/stats/$statsFile.tsv' with lines title '$label', "
    done
    #
    # plot bps average, bestN bps results, cumsum ctime avg (all and best)
    output="$plotsFolder/$statsFile.pdf";
    #
    # define y ranges
    ymin="$bps_min"
    ymax="$bps_max"
    labelDetail="$(echo $statsFile|awk -F'_' '{print $NF}')"
    [[ "$labelDetail" == "s" ]] && ymin="$tmin_s" && ymax="$max_s"
    [[ "$labelDetail" == "m" ]] && ymin="$tmin_m" && ymax="$max_m"
    [[ "$labelDetail" == "h" ]] && ymin="$tmin_h" && ymax="$max_h"
    #
    # define y label
    [[ "$statsFile" == "bps"* ]] && ylabel="bPS ($labelDetail)" || ylabel="TIME ($labelDetail)"
gnuplot << EOF
    # set title "BPS average (all)"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    #set key outside top horizontal Right noreverse noenhanced autotitle nobox
    set grid
    #
    # Set up the axis on the left side for bps
    set ylabel "$ylabel"
    set ytics nomirror
    # set yrange [$ymin:$ymax]
    #
    # set up the axis below for generation
    set xlabel "Generation"
    set xtics nomirror
    set xrange [$first_gen:$last_gen]
    #
    set output "$output"
    #
    plot $plotGAs
EOF
done
