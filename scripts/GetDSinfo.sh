#!/bin/bash
#
# === FUNCTIONS ===========================================================================
#
function REFORMAT_DS_SIZES() {
    (printf ":\t:\tRAW:DATA\tBASE:2\tBASE:2\tBASE:2\n";
    awk -F',' '{ 
        print "DS"++i"\t"$1"\t"$2":bytes\t"$2/2^10":KB\t"$2/2^20":MB\t"$2/2^30":GB\t"$3;
    }' $dsToSizeTMP) | column -t | tr ":" " " > $DS_sizesBase2; 
    #
    (printf ":\t:\tRAW:DATA\tBASE:10\tBASE:10\tBASE:10\n";
    awk -F',' '{ 
        print "DS"++i"\t"$1"\t"$2":bytes\t"$2/10^3":KB\t"$2/10^6":MB\t"$2/10^9":GB\t"$3;
    }' $dsToSizeTMP) | column -t | tr ":" " " > $DS_sizesBase10;
}
#
# === DEFAULT VALUES ===========================================================================
#
#
dsToSizeTMP="../../dsToSizeTMP.csv";
numHeadersPerDS="../../DS_numHeaders.tsv";
DS_sizesBase2="../../DS_sizesBase2.tsv";
DS_sizesBase10="../../DS_sizesBase10.tsv";
#
sizes=("grp1" "grp2" "grp3" "grp4" "grp5");
sizes_bytes=(1048576 104857600 1073741824 3117292070 3117292070);
#
declare -A dsToSize;
#
rawSequencesPath="../../sequences_raw";
sequencesPath="../../sequences";
seqFiles=( $sequencesPath/*.seq );
#
# === MAIN ===========================================================================
#
# add size data to dsToSize structure
for seqFile in "${seqFiles[@]}"; do
    seq_num_bytes=`ls -la $seqFile | awk '{ print $5 }'`;
    #
    ds="${seqFile%.*}"
    dsName=$(basename "$ds");
    sucess=false;
    #
    first=${sizes_bytes[0]};
    if (( seq_num_bytes < first )); then # lower than 1MB
        dsToSize[$dsName]=${sizes[0]};
        success=true;
    fi
    #
    length=$(( ${#sizes_bytes[@]} - 3 ))
    for ((i = 0; i <= length; i++ )); do
        lower_elem=${sizes_bytes[i]};
        higher_elem=${sizes_bytes[i+1]}
        if (( seq_num_bytes >= lower_elem && seq_num_bytes < higher_elem )); then # lower than 100MB
            dsToSize[$dsName]=${sizes[$((i+1))]};
            success=true;
        fi
    done
    #
    last=${sizes_bytes[-1]}
    if (( seq_num_bytes >= last )); then # higher than or equal to 1GB
        dsToSize[$dsName]=${sizes[-1]};
        success=true;
    fi
    #
    if [ ! "$success" ]; then
        echo "error assigning ds$gen_i to a group";
    fi
done
#
# iterate over the hashmap to save it into a file
for ds in "${!dsToSize[@]}"; do
    bytes=`ls -la $sequencesPath/$ds.seq | awk '{ print $5 }'`;
    size="${dsToSize[$ds]}";
    echo "$ds,$bytes,$size";
done > "$dsToSizeTMP";
#
# order datasets from smallest to largest
sort -t ',' -k2,2n -o $dsToSizeTMP $dsToSizeTMP;
#
# get num of headers of each raw .fa
find $rawSequencesPath -maxdepth 1 -type f -exec sh -c 'echo -n "$(basename {} | sed "s/_raw\.fa/ /")\t$(grep -o ">" {} | wc -l):headers\n";' \; | column -t | tr ':' ' '> $numHeadersPerDS;
sort -k2,2n -o $numHeadersPerDS $numHeadersPerDS;
#
REFORMAT_DS_SIZES;
#
rm -fr $dsToSizeTMP;
