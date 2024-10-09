#!/bin/bash
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
seqArr=("human12d5MB" "human25MB" "human50MB" "human100MB")
#
# output="../humanSampling"
# mkdir -p $output
# pltsFolder="$output/plots"
# mkdir -p $pltsFolder
# statsFolder="$output/stats"
# mkdir -p $statsFolder
#
# second sampling plot
#
sequence="chm13v2.0"
dsx=$(awk '/'$sequence'[[:space:]]/ { print $1 }' "$ds_sizesBase2")
mkdir -p "../$dsx/sampling2"
labelAndCmdTable="../$dsx/sampling2/labelCmdTable.tsv"
script="../$dsx/sampling2/g1.sh"
#
# create table where first column is a label indicating the sequence size for which the parameters were previously optimized for,
# and second column for command with those parameters but applied to larger size (100MB or ~3GB)
( for idx in "${!seqArr[@]}"; do
    dsx=$(awk '/'${seqArr[idx]}'[[:space:]]/ { print $1 }' "$ds_sizesBase2")
    results="../$dsx/sampling/eval/allSortedRes_bps.tsv"
    awk -v label="${seqArr[idx]}" -v new=$sequence -F'\t' 'NR==3 {gsub(label, new, $NF); print label"\t"$NF}' $results 
done ) > $labelAndCmdTable
#
( for idx in "${!seqArr[@]}"; do
    dsx=$(awk '/'${seqArr[idx]}'[[:space:]]/ { print $1 }' "$ds_sizesBase2")
    results="../$dsx/sampling/eval/allSortedRes_bps.tsv"
    awk -v label="${seqArr[idx]}" -v new=$sequence -F'\t' 'NR==3 {gsub(label, new, $NF); print $NF}' $results 
done ) > $script
#
# dsx=$(awk '/'human100MB'[[:space:]]/ { print $1 }' "$ds_sizesBase2")
# results="../$dsx/s150gens/eval/allSortedRes_bps.tsv"
# awk -v label="${seqArr[idx]}" -v new=$sequence -F'\t' 'NR==3 {gsub(label, new, $NF); print $NF" # "label}' $results >> $script
#
chmod +x $script
bash -x ./Run.sh -ds $dsx -ga sampling2 -g 1 --timeout 64800 1> runout 2> runerr &
wait
#
# replace values from program column with labels
rawRes="../$dsx/sampling2/eval/rawRes.tsv"
awk 'BEGIN {FS=OFS="\t"} 
FNR==NR {label[$2]=$1; next} 
{
    for (cmd in label) {
        if ($9 == cmd) {
            $1 = label[cmd]
        }
    }
    print $0
}' $labelAndCmdTable $rawRes | awk '{$2}' > tmp.tsv
awk -F'\t' '{
    # in sampling, results that took too much RAM should be considered equaly valid to properly 
    # evaluate sample results by BPS
    if ($2 ~ /^[0-9]+\.[0-9]+$/) { 
        $2 = 0 
    } 
    print
}' OFS='\t' tmp.tsv > $rawRes
rm -fr tmp.tsv
#
statsFile="../$dsx/sampling2/eval/allSortedRes_bps.tsv"
./Evaluation.sh --moga -wBPS 0.5 -ds $dsx -ga sampling2 -g 1
#
mkdir -p "../$dsx/sampling2/stats"
statsFileProcessed="../$dsx/sampling2/stats/samplingProcessed2.tsv"
mkdir -p "../$dsx/sampling2/plots"
pltsFile="../$dsx/sampling2/plots/sampling2.pdf"
#
awk -F'\t' 'NR>1{
    #
    if (NR==2) filesizePerc="SIZE_PERC"
    else if ($0 ~ /12d5MB/) filesizePerc=12.5
    else if ($0 ~ /25MB/) filesizePerc=25
    else if ($0 ~ /50MB/) filesizePerc=50
    else if ($0 ~ /100MB/) filesizePerc=100
    #
    print filesizePerc"\t"$2"\t"$5"\t"$6"\t"$7"\t"$8
}' $statsFile | sort -n -k1,1 > $statsFileProcessed
#
gnuplot -persist << EOF
    # set title "Sampling"
    set terminal pdfcairo enhanced color font 'Verdade,12'
    set output "$pltsFile"
    set key outside top horizontal Right noreverse noenhanced autotitle nobox

    set xlabel "\nVersions of the complete human sequence"
    set format x "V%g"  # Format x-axis as V1, V2, etc.
    set xtics ("V1\n(100MB)" 100, "V2\n(50MB)" 50, "V3\n(25MB)" 25, "V4\n(12.5MB)" 12.5) 
    set xrange [103:3]

    set ylabel "BPS"
    set ytics nomirror
    set yrange [1.43:1.69]

    set y2label "C TIME (m)"
    set y2tics nomirror
    set y2range [0.45:7.1]

    set style line 1 lc rgb '#550055' pt 2 ps 1 # BPS dots
    set style line 2 lt 1 lc rgb '#990099' ps 1 # BPS line

    set style line 3 lc rgb '#005500' pt 2 ps 0.5 # ctime dots
    set style line 4 lt 1 lc rgb '#009900' ps 1 dashtype '_-' # ctime line

    set grid
    plot '$statsFileProcessed' using 1:3 linestyle 1 notitle, \
    '$statsFileProcessed' using 1:3 linestyle 2 with lines title "BPS", \
    '$statsFileProcessed' using 1:3:3 with labels offset char 1.5,-1 notitle, \
    '$statsFileProcessed' u 1:5 linestyle 3 axes x1y2 notitle, \
    '$statsFileProcessed' u 1:5 linestyle 4 axes x1y2 with lines title "C TIME (m)"
EOF
