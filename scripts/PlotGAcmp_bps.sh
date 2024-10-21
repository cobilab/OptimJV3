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
bpsArr=("bps_avg_all" "bps_best1")
#
for bpsFilename in "${bpsArr[@]}"; do
    #
    # list of choosen GAs
    gaArr=( "e0_ga1_lr0_cmga" $(ls "$dsFolder" | grep -E "^($experiment)") )
    plotGAs=""
    for ga in "${gaArr[@]}"; do
        GET_LABEL "$ga"
        [[ "$ga" == *"_continuation" ]] && continue
        plotGAs+="'$dsFolder/$ga/stats/$bpsFilename.tsv' with lines title '$label', "
    done
    #
    # plot bps average, bestN bps results, cumsum ctime avg (all and best)
    output="$plotsFolder/$bpsFilename.pdf";
gnuplot << EOF
    # set title "BPS average (all)"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    #set key outside top horizontal Right noreverse noenhanced autotitle nobox
    set grid
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
    set output "$output"
    #
    plot $plotGAs
EOF
done
