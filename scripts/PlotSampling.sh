#!/bin/bash
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
seqArr=("human12d5MB" "human25MB")
output="../humanSampling"
mkdir -p $output
pltsFolder="$output/plots"
mkdir -p $pltsFolder
statsFolder="$output/stats"
mkdir -p $statsFolder
statsFile="$statsFolder/sampling.tsv"
statsFileProcessed="$statsFolder/samplingProcessed.tsv"
pltsFile="$pltsFolder/sampling.pdf"
#
( for idx in "${!seqArr[@]}"; do
    dsx=$(awk '/'${seqArr[idx]}'[[:space:]]/ { print $1 }' "$ds_sizesBase2")
    results="../$dsx/sampling/eval/allSortedRes_bps.tsv"
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
    # Now parts[n] contains the "filesize.extension", so remove the extension
    filesize = parts[n];
    #
    # Remove the extension by replacing anything after the last "."
    sub(/\.[^.]*$/, "", filesize);
    #
    if (NR==1) filesize="SIZE_MB"
    else if (filesize ~ /12d5MB/) filesize=12.5
    else if (filesize ~ /25MB/) filesize=25
    else if (filesize ~ /50MB/) filesize=50
    else if (filesize ~ /100MB/) filesize=100
    #
    print filesize"\t"$5"\t"$6"\t"$7"\t"$8
}' $statsFile > $statsFileProcessed
#
# gnuplot
gnuplot -persist << EOF
    # set title "Sampling"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$pltsFile"

    set xlabel "Sequence Size"

    set ylabel "BPS"
    set yrange [1.6:1.8]

    set style line 1 lc rgb '#550055' pt 2 ps 1 # BPS dots
    set style line 2 lt 1 lc rgb '#990099' ps 1 # BPS line

    set grid
    plot '$statsFileProcessed' using 1:2 linestyle 1 title 'BPS', \
    '$statsFileProcessed' using 1:2 linestyle 2 with lines notitle, \
    '$statsFileProcessed' using 1:2:2 with labels offset char 1,1 notitle
    # '$statsFileProcessed' using 1:2:1 with vectors nohead notitle, \
    
EOF
