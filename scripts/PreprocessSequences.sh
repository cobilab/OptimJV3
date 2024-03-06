
#!/bin/bash


binPath="../bin";

rawSequencesPath="../../sequences_raw";
sequencesPath="../../sequences";

mkdir -p $sequencesPath;

rawFaFiles=( $rawSequencesPath/*_raw.fa )

#
# === _raw.fa ---> clean .fa ===========================================================================
#
printf "\n*_raw.fa ---cleaning...---> *.fa\n"
for rawFaFile in "${rawFaFiles[@]}"; do
    fileBasename=$(basename "$rawFaFile" _raw.fa)
    
    cleanFaFile="${sequencesPath}/${fileBasename}.fa";

    if [[ ! -f $cleanFaFile ]]; then
        # this cleaning implies removing all of their headers...
        $binPath/gto_fasta_to_seq < $rawFaFile | tr 'agct' 'AGCT' | tr -d -c "AGCT" | $binPath/gto_fasta_from_seq -n x -l 80 > $cleanFaFile
        echo "$cleanFaFile created with success"
    else
        echo "$cleanFaFile has been previously created"
    fi
done

cleanFaFiles=( $sequencesPath/*.fa )

#
# === *.fa ------> *.seq ===========================================================================
#
printf "\nclean .fa ---preprocessing...---> *.seq\n"
for cleanFaFile in "${cleanFaFiles[@]}"; do
    seqFile=$(echo $cleanFaFile | sed 's/.fa/.seq/g');
    if [[ ! -f $seqFile ]]; then
        cat "$cleanFaFile" | grep -v ">" | tr 'agct' 'AGCT' | tr -d -c "ACGT" > "$seqFile" # removes lines with comments and non-nucleotide chars
        echo "$seqFile created with success"
    else
        echo "$seqFile has been previously created"
    fi
done
