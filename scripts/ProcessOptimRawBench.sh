#!/bin/bash

resultsPath="../optimRes";
optimCmds="optimCmds";
mkdir -p $optimCmds;

numBestRes=20;

sizes=("xs" "s" "m" "l" "xl");

#
# === FUNCTIONS ===========================================================================
#
function FILTER_INNACURATE_DATA() {
    rawGrps=("-raw");
    cleanGrps=("");
    #
    for size in ${sizes[@]}; do
        rawGrps+=("-raw-$size");
        cleanGrps+=("-grp-$size");
    done
    
    # new results may have size grps different from previous grps, so old results are removed
    rm -fr $resultsPath/*.csv
    rm -fr $resultsPath/split*
    
    # remove tests that failed to compress the sequence
    for i in ${!rawGrps[@]}; do
        rawGrp="${rawGrps[$i]}"
        rawFile="$resultsPath/bench-results$rawGrp.txt"
        
        cleanGrp="${cleanGrps[$i]}"
        cleanFile="$resultsPath/bench-results$cleanGrp.csv"
        
        if [ -f "$rawFile" ]; then
             awk '{flag=0; for(i=1; i<=NF; i++) if ($i == -1) {flag=1; next}; if (flag==0) print $0}' "$rawFile" > "$cleanFile";
        fi
    done
}
#
function SPLIT_FILES_BY_DS() {
    # read the input file
    file_prefix="$resultsPath/bench-results-"
    
    # remove datasets before recreating them
    rm -fr ${file_prefix}DS*-*.csv
    
    ds_i=0;
    for input_file in ${clean_bench_grps[@]}; do
        while IFS= read -r line; do
            # check if the line contains a dataset name
            if [[ $line == DS* ]]; then
                # create a new output file for the dataset
                DSN=$(echo "$line" | cut -d" " -f1)
                size=$(echo "$line" | cut -d" " -f5)
                
                output_file="${file_prefix}$DSN-$size.csv"
                
                echo "$line" > "$output_file"
            else
                # append the line to the current dataset's file
                echo "$line" >> "$output_file"
            fi
        done < "$input_file"
    done
}

#
# === MAIN ===========================================================================
#

# parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --num-best-res|-n)
            numBestRes="$2"
            shift
            shift
        ;;
        *) 
            # ignore any other arguments
            shift
        ;;
    esac
done

# bench-results-raw-$size.txt ----> bench-results-grp-$size.csv
FILTER_INNACURATE_DATA;

# bench-results-grp-$size.csv ----> bench-results-DS1-$size.csv, bench-results-DS2-$size.csv...
clean_bench_grps=( $(find "$resultsPath" -maxdepth 1 -type f -name "*-grp-*" | sort -t '-' -k2,2 -k4,4 -r) );
SPLIT_FILES_BY_DS;

#
# === MAIN: OTIMIZATION CODE =============================================================
#
# filter each DS so that they contain the N best tests and commands
dsFiles=($(find $resultsPath -maxdepth 1 -type f -name 'bench-results-DS*-*.csv'));
for dsFile in ${dsFiles[@]}; do
    dsFileTMP="${dsFile/.csv/-TMP.csv}";

    # get N best results
    sort -nk4,4 -nk5,5 $dsFile | head -n $((2+numBestRes)) > $dsFileTMP;

    # get N best commands
    topNcmds="${dsFile/bench-results/bench-results-top$numBestRes.sh}";
    topNcmds="optimJV3cmds/$(basename $topNcmds)";
    tail -n +3 $dsFileTMP  | awk '{print substr($0, index($0, "../bin/JARVIS3"))}' > $topNcmds;

    rm -fr $dsFile;
    mv $dsFileTMP $dsFile;
done

# the .csv clean grps files needs to be updated to contain only the N best results of each DS
for clean_grp in ${clean_bench_grps[@]}; do
    rm -fr $clean_grp;
    touch $clean_grp;

    size="${clean_grp#*-grp-}";
    size="${size%%.*}";

    dsFilesSizeX=($(find $resultsPath -maxdepth 1 -type f -name bench-results-DS*-$size.csv | sort -V));
    for dsFileSizeX in ${dsFilesSizeX[@]}; do 
        cat $dsFileSizeX >> $clean_grp;
    done 
done

