#!/bin/bash
#
output_file="dsToSize.csv";
#
sizes=("xs" "s" "m" "l" "xl");
sizes_bytes=(1048576 104857600 1073741824 10737418240 10737418240);
#
declare -A dsToSize;
#
sequencesPath="$HOME/sequences";
seqFiles=( $sequencesPath/*.seq );
#
# ==============================================================================
#

# add data to dsToSize structure
for seqFile in "${seqFiles[@]}"; do
    seq_num_bytes=`ls -la $seqFile | awk '{ print $5 }'`;

    ds="${seqFile%.*}"
    dsName=$(basename "$ds");
    sucess=false;

    first=${sizes_bytes[0]};
    if (( seq_num_bytes < first )); then # lower than 1MB
        dsToSize[$dsName]=${sizes[0]};
        success=true;
    fi

    length=$(( ${#sizes_bytes[@]} - 3 ))
    for ((i = 0; i <= length; i++ )); do
        lower_elem=${sizes_bytes[i]};
        higher_elem=${sizes_bytes[i+1]}
        if (( seq_num_bytes >= lower_elem && seq_num_bytes < higher_elem )); then # lower than 100MB
            dsToSize[$dsName]=${sizes[$((i+1))]};
            success=true;
        fi
    done

    last=${sizes_bytes[-1]}
    if (( seq_num_bytes >= last )); then # higher than or equal to 10GB
        dsToSize[$dsName]=${sizes[-1]};
        success=true;
    fi

    if [ ! "$success" ]; then
        echo "error assigning ds$gen_i to a grp"
    fi
done

# iterate over the hashmap and write to the CSV file
echo "ds,bytes,size" > "$output_file"  # write the header row
for ds in "${!dsToSize[@]}"; do
    bytes=`ls -la $sequencesPath/$ds.seq | awk '{ print $5 }'`;
    size="${dsToSize[$ds]}"
    echo "$ds,$bytes,$size" >> "$output_file"
done

# order datasets from smallest to largest
(head -n 1 $output_file && tail -n +2 $output_file | sort -t',' -k2,2n) > dsToSize-tmp.csv

cp dsToSize-tmp.csv $output_file
rm -fr dsToSize-tmp.csv
