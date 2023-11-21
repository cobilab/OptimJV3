#!/bin/bash
#
configJson="../config.json"
ds_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
ds_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )"
#
ga="sampling100gens"
sequence="human"
y2min="*"
y2Max="*"
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -v|--view-ds|--view-datasets)
        cat $ds_sizesBase2; echo
        exit;
        ;;
    -a|-ga|--algorithm|--genetic-algorithm)
        ga="$2";
        shift 2; 
        ;;
    -s|--sequence)
        sequence="$2"
        shift 2;
        ;;
    -y2|--y2-range|--ctime-range)
        y2Range="$2";
        y2min="$(echo $y2Range | cut -d ':' -f1)"
        y2Max="$(echo $y2Range | cut -d ':' -f2)"
        shift 2;
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
availableSeqs=$(awk '{ print $2 }' "$ds_sizesBase2")
if echo "$sequence" | grep -q "$availableSeqs" || [[ $sequence == "human" ]] || [[ $sequence == "cassava" ]]; then
    seqArr=("${sequence}12d5MB" "${sequence}25MB" "${sequence}50MB" "${sequence}100MB")
    output="../${sequence}Sampling"
else
    echo "Input sequence not found"
    echo "To view available sequences, execute ./Sampling.sh -v"
    exit;
fi
#
mkdir -p $output
pltsFolder="$output/plots"
mkdir -p $pltsFolder
statsFolder="$output/stats"
mkdir -p $statsFolder
statsFile="$statsFolder/$ga.tsv"
statsFileProcessed="$statsFolder/processed_$ga.tsv"
pltsFile="$pltsFolder/$ga.pdf"
#
( for idx in "${!seqArr[@]}"; do
    dsx=$(awk '/'${seqArr[idx]}'[[:space:]]/ { print $1 }' "$ds_sizesBase2")
    results="../$dsx/$ga/eval/allSortedRes_bps.tsv"
    [ $idx -eq 0 ] && awk -F'\t' 'NR==2' $results 
    awk -F'\t' 'NR==3' $results 
done ) > $statsFile
#
# process stats so that x axis is size of sequence and y axis is BPS
awk -F'\t' '{
    # 
    # Split the last field (command) using "/" to get rid of the path
    n = split($NF, parts, "/");
    #
    # Now parts[n] contains the "filesizePerc.extension", so remove the extension
    filesizePerc = parts[n];
    #
    # Remove the extension by replacing anything after the last "."
    sub(/\.[^.]*$/, "", filesizePerc);
    #
    if (NR==1) filesizePerc="SIZE_PERC"
    else if (filesizePerc ~ /12d5MB/) filesizePerc=12.5
    else if (filesizePerc ~ /25MB/) filesizePerc=25
    else if (filesizePerc ~ /50MB/) filesizePerc=50
    else if (filesizePerc ~ /100MB/) filesizePerc=100
    #
    print filesizePerc"\t"$5"\t"$6"\t"$7"\t"$8
}' $statsFile > $statsFileProcessed
#
# gnuplot
gnuplot << EOF
    set title "Sampling"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$pltsFile"
    set key outside top horizontal Right noreverse noenhanced autotitle nobox

    set xlabel "Sequence Size (%)"
    set format x "%g%%"  # Append % symbol to each x-axis tic
    set xtics (100, 50, 25, 12.5)
    set xrange [103:3]

    set ylabel "BPS"
    set ytics nomirror
    set yrange [.769:1]

    set y2label "C TIME (m)"
    set y2tics nomirror
    set y2range [$y2min:$y2Max]

    set style line 1 lc rgb '#550055' pt 2 ps 1 # BPS dots
    set style line 2 lt 1 lc rgb '#990099' ps 1 # BPS line

    set style line 3 lc rgb '#005500' pt 2 ps 0.5 # ctime dots
    set style line 4 lt 1 lc rgb '#009900' ps 1 dashtype '_-' # ctime line

    set grid
    plot '$statsFileProcessed' u 1:2 linestyle 1 notitle, \
    '$statsFileProcessed' u 1:2 linestyle 2 with lines title "BPS", \
    '$statsFileProcessed' u 1:2:2 with labels offset char 1.5,-1 notitle, \
    '$statsFileProcessed' u 1:4 linestyle 3 axes x1y2 notitle, \
    '$statsFileProcessed' u 1:4 linestyle 4 axes x1y2 with lines title "C TIME (m)"
EOF
