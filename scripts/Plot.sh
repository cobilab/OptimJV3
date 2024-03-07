#!/usr/bin/env bash

resultsPath="../optimRes";

sizes=("xs" "s" "m" "l" "xl");

csv_dsToSize="dsToSize.csv";
declare -A dsToSize;

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
function LOAD_CSV_DSTOSIZE() {
  while IFS=, read -r ds bytes size; do
    # Skip the header line
    if [[ "$ds" != "ds" ]]; then
      dsToSize[$ds]=$size;
    fi
  done < $csv_dsToSize;
}
#
function SPLIT_FILE_BY_COMPRESSOR() {
  # recreate grp folder
  rm -fr $plots_folder;
  mkdir -p $plots_folder;

  CHECK_INPUT "$bench_res_csv";
  # create names.txt inside each ds folder; it contains all compressor names
  cat $bench_res_csv | awk '{ print $1} ' | sort -V | uniq | grep -vE "DS\*|PROGRAM" > "$compressor_names";
  CHECK_INPUT "$compressor_names";

  # splits ds into subdatasets by compressor and store them in folder
  c_i=1;
  plotnames="";
  plotnames_log="";
  mapfile -t INT_DATA < "$compressor_names";
  for dint in "${INT_DATA[@]}"; do
    if [[ $dint != PROGRAM && $dint != DS* ]]; then
      compressor_csv="$compressor_csv_prefix$c_i.csv";
      grep $dint $bench_res_csv > "$compressor_csv";
      
      tmp="'$compressor_csv' u 4:5 w points ls $c_i title '$dint', ";
      plotnames="$plotnames $tmp";
      
      tmp_log="'$compressor_csv' u 4:(pseudo_log(5)) w points ls $c_i title '$dint', ";
      plotnames_log="$plotnames_log $tmp_log";
      
      ((++c_i));
    fi
  done

  echo -e "${plotnames//, /\\n}";
  echo -e "${plotnames_log//, /\\n}";
}
#
function GET_PLOT_BOUNDS() {
    # row structure: Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
    Rscript -e 'summary(as.numeric(readLines("stdin")))' < <(awk '{if ($4 ~ /^[0-9.]+$/) print $4}' $csvFile) > tempX.txt
    bps_min=$(awk 'NR==2{print $1}' "tempX.txt");
    bps_Q1=$(awk 'NR==2{print $2}' "tempX.txt");
    bps_Q3=$(awk 'NR==2{print $5}' "tempX.txt");
    bps_max=$(awk 'NR==2{print $6}' "tempX.txt");

    # row structure: Min. 1st Qu.  Median    Mean 3rd Qu.    Max.
    Rscript -e 'summary(as.numeric(readLines("stdin")))' < <(awk '{if ($5 ~ /^[0-9.]+$/) print $5}' $csvFile) > tempY.txt
    bytesCF_Q1=$(awk 'NR==2{print $2}' "tempY.txt");
    bytesCF_Q3=$(awk 'NR==2{print $5}' "tempY.txt");

    # IQR (Inter Quartile Range) = Q3 - Q1
    bps_IQR=$(echo "$bps_Q3-$bps_Q1" | bc);
    bytesCF_IQR=$(echo "$bytesCF_Q3-$bytesCF_Q1" | bc);

    # lower bound = Q1 – c*IQR
    bps_lowerBound=$bps_min # $(echo "$bps_Q1+0.4*$bps_IQR" | bc);
    bytesCF_lowerBound=$(echo "$bytesCF_Q1-0.075*$bytesCF_IQR" | bc);

    # upper bound = Q3 + c*IQR
    bps_upperBound=$bps_max # $(echo "$bps_Q3+0.3*$bps_IQR" | bc);
    bytesCF_upperBound=$(echo "$bytesCF_Q3+0.075*$bytesCF_IQR" | bc);

    # if (( $(echo "$bps_lowerBound < 0" | bc -l) )); then
    #   bps_lowerBound=-0.01;
    # fi

    # if (( $(echo "$bps_upperBound > 2.5" | bc -l) )); then
    #   bps_upperBound=2.5;
    # fi

    # if (( $(echo "$bytesCF_lowerBound < 0" | bc -l) )); then
    #   bytesCF_lowerBound=-0.01;
    # fi

    # if (( $(echo "$bps_IQR < 1" | bc -l) )); then
    #   bps_lowerBound="$bps_Q1";
    #   bps_upperBound="$bps_Q3";
    # fi

    # if (( $(echo "$bytesCF_IQR < 1" | bc -l) )); then
    #   bytesCF_lowerBound="$bytesCF_Q1";
    #   bytesCF_upperBound="$bytesCF_Q3";
    # fi

    cat tempX.txt;
    printf "bps Q1: $bps_Q1 \n";
    printf "bps Q3: $bps_Q3 \n";
    printf "bps IQR: $bps_IQR \n";
    printf "bps lower bound: $bps_lowerBound \n";
    printf "bps upper bound: $bps_upperBound \n";

    cat tempY.txt;
    printf "bytesCF Q1: $bytesCF_Q1 \n";
    printf "bytesCF Q3: $bytesCF_Q3 \n";
    printf "bytesCF IQR: $bytesCF_IQR \n";
    printf "bytesCF lower bound: $bytesCF_lowerBound \n";
    printf "bytesCF upper bound: $bytesCF_upperBound \n\n";

    # rm -fr tempX.txt tempY.txt;
}
#
function PLOT() {
  gnuplot << EOF
    reset
    set title "$plot_title"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$plot_file"
    set style line 101 lc rgb '#000000' lt 1 lw 2 
    set border 3 front ls 101
    # set tics nomirror out scale 0.01
    set key outside right top vertical Right noreverse noenhanced autotitle nobox
    set style histogram clustered gap 1 title textcolor lt -1
    set xtics border in scale 0,0 nomirror rotate by -45 autojustify
    set yrange [$bytesCF_lowerBound:$bytesCF_upperBound]
    set xrange [$bps_lowerBound:$bps_upperBound]
    set xtics auto
    set ytics auto
    set format x "%.3f"  # set format to three decimals
    set key top right
    set style line 1 lc rgb '#990099'  pt 1 ps 0.6  # circle
    set style line 2 lc rgb '#004C99'  pt 2 ps 0.6  # circle
    set style line 3 lc rgb '#CCCC00'  pt 3 ps 0.6  # circle
    #set style line 4 lc rgb '#CC0000' lt 2 dashtype '---' lw 4 pt 5 ps 0.4 # --- red
    set style line 4 lc rgb 'red'  pt 7 ps 0.6  # circle 
    set style line 5 lc rgb '#009900'  pt 5 ps 0.6  # circle
    set style line 6 lc rgb '#990000'  pt 6 ps 0.6  # circle
    set style line 7 lc rgb '#009999'  pt 4 ps 0.6  # circle
    set style line 8 lc rgb '#99004C'  pt 8 ps 0.6  # circle
    set style line 9 lc rgb '#CC6600'  pt 9 ps 0.6  # circle
    set style line 10 lc rgb '#322152' pt 10 ps 0.6  # circle    
    set style line 11 lc rgb '#425152' pt 11 ps 0.6  # circle    
    set grid
    set ylabel "Compression time (s)"
    set xlabel "Average number of bits per symbol"
    plot $plotnames
EOF
}
#
function PLOT_LOG() {
  gnuplot << EOF
    reset

    # define a function to adjust zero or near-zero values
    pseudo_log(x) = (x <= 0) ? -10 : log10(x)

    set title "$plot_title_log"
    set logscale xy 2
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$plot_file_log"
    set style line 101 lc rgb '#000000' lt 1 lw 2 
    set border 3 front ls 101
    # set tics nomirror out scale 0.01
    set key outside right top vertical Right noreverse noenhanced autotitle nobox
    set style histogram clustered gap 1 title textcolor lt -1
    set xtics border in scale 0,0 nomirror rotate by -45 autojustify
    set yrange [1e-10:$bytesCF_upperBound]
    set xrange [$bps_lowerBound:$bps_upperBound]
    set xtics auto
    set ytics auto
    set format x "%.3f"  # set format to three decimals
    set key top right
    set style line 1 lc rgb '#990099'  pt 1 ps 0.6  # circle
    set style line 2 lc rgb '#004C99'  pt 2 ps 0.6  # circle
    set style line 3 lc rgb '#CCCC00'  pt 3 ps 0.6  # circle
    #set style line 4 lc rgb '#CC0000' lt 2 dashtype '---' lw 4 pt 5 ps 0.4 # --- red
    set style line 4 lc rgb 'red'  pt 7 ps 0.6  # circle 
    set style line 5 lc rgb '#009900'  pt 5 ps 0.6  # circle
    set style line 6 lc rgb '#990000'  pt 6 ps 0.6  # circle
    set style line 7 lc rgb '#009999'  pt 4 ps 0.6  # circle
    set style line 8 lc rgb '#99004C'  pt 8 ps 0.6  # circle
    set style line 9 lc rgb '#CC6600'  pt 9 ps 0.6  # circle
    set style line 10 lc rgb '#322152' pt 10 ps 0.6  # circle    
    set style line 11 lc rgb '#425152' pt 11 ps 0.6  # circle    
    set grid
    set ylabel "Compression time (s)"
    set xlabel "Average number of bits per symbol"
    plot $plotnames_log
EOF
}

#
# === MAIN ===========================================================================
#

# while [[ $# -gt 0 ]]; do
#     key="$1"
#     case $key in
#         --dir|-d)
#             resultsPath="../optimResGen";
#         *) 
#             # ignore any other arguments
#             shift
#         ;;
#     esac
# done

LOAD_CSV_DSTOSIZE;

#
# === MAIN: PLOT EACH DS ===========================================================================
#
clean_bench_dss=( $(find "$resultsPath" -maxdepth 1 -type f -name "*bench-results-DS*-*.csv" | sort -t ' ' -k2n) );
for clean_ds in ${clean_bench_dss[@]}; do
  header=$(head -n 1 "$clean_ds")
  IFS=' - ' read -r DSX genome size <<< "$header" # split the header into variables

  # str_time="m";
  # if [ "$size" = "xs" ] || [ "$size" = "s" ]; then # smaller files => faster tests => time measured in seconds
  #   str_time="s";
  # fi

  gen_i=${DSX#DS};
  str_genome=${genome//_/ }

  csvFile=$clean_ds;

  plots_folder="$resultsPath/plot_ds${gen_i}_${size}";
  bench_res_csv="$resultsPath/bench-results-DS${gen_i}-${size}.csv";
  compressor_names="$plots_folder/names_ds$gen_i.txt";
  compressor_csv_prefix="$plots_folder/bench-results-DS$gen_i-c";

  plot_file="$resultsPath/plot_ds${gen_i}_${size}/bench-plot-ds$gen_i-$size.pdf";
  plot_file_log="$resultsPath/plot_ds${gen_i}_${size}/bench-plot-ds$gen_i-$size-log.pdf";

  plot_title="Compression efficiency of $str_genome";
  plot_title_log="Compression efficiency of $str_genome (log scale)";

  SPLIT_FILE_BY_COMPRESSOR;
  GET_PLOT_BOUNDS;
  PLOT;
  PLOT_LOG;
done

#
# === MAIN: PLOT EACH GRP OF DSs BY SIZE ===========================================================================
#
clean_bench_grps=( $(find "$resultsPath" -maxdepth 1 -type f -name "*-grp-*" | sort -t '-' -k2,2 -k4,4 -r) );
for clean_grp in ${clean_bench_grps[@]}; do
    suffix="${clean_grp##*-grp-}";   # remove everything before the last occurrence of "-grp-"
    size="${suffix%%.*}";            # remove everything after the first dot

    # str_time="m";
    # if [ "$size" = "xs" ] || [ "$size" = "s" ]; then # smaller files => faster tests => time measured in seconds
    #   str_time="s";
    # fi

    csvFile=$clean_grp;

    plots_folder="$resultsPath/plot_grp_$size";
    bench_res_csv="$resultsPath/bench-results-grp-$size.csv";
    compressor_names="$plots_folder/names_grp_$size.txt";
    compressor_csv_prefix="$plots_folder/bench-results-grp-$size-c";

    plot_file="$resultsPath/plot_grp_$size/bench-plot-grp-$size.pdf";
    plot_file_log="$resultsPath/plot_grp_$size/bench-plot-grp-$size-log.pdf";

    plot_title="Compression efficiency of sequences from group $size";
    plot_title_log="Compression efficiency of sequences from group $size (log scale)";

    SPLIT_FILE_BY_COMPRESSOR;
    GET_PLOT_BOUNDS;
    PLOT;
    PLOT_LOG;
done
