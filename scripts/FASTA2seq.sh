#!/bin/bash
#
configJson="../config.json"
toolsPath="$(grep 'toolsPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
rawSequencesPath="$(grep 'rawSequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
mkdir -p $sequencesPath;
#
rawFaFiles=( $rawSequencesPath/*_raw.fa );
#
# === _raw.fa ---> clean .fa ===========================================================================
#
printf "\n*_raw.fa ---cleaning...---> *.fa\n";
for rawFaFile in "${rawFaFiles[@]}"; do
    # 
    # empty space before "_raw.fa" removes "_raw.fa" from fileBasename
    fileBasename=$(basename "$rawFaFile" _raw.fa);
    #
    cleanFaFile="${sequencesPath}/${fileBasename}.fa";
    #
    if [[ ! -f $cleanFaFile ]]; then
        # this cleaning implies removing all of their headers...
        $toolsPath/gto_fasta_to_seq < $rawFaFile | tr 'agct' 'AGCT' | tr -d -c "AGCT" | $toolsPath/gto_fasta_from_seq -n x -l 80 > $cleanFaFile;
        echo -e "\033[32mnew clean fasta: $cleanFaFile \033[0m";
    else
        echo "already exists: $cleanFaFile has been previously created";
    fi
done
#
cleanFaFiles=( $sequencesPath/*.fa );
#
# === *.fa ------> *.seq ===========================================================================
#
printf "\nclean .fa ---preprocessing...---> *.seq\n"
for cleanFaFile in "${cleanFaFiles[@]}"; do
    seqFile=$(echo $cleanFaFile | sed 's/.fa/.seq/g');
    if [[ ! -f $seqFile ]]; then
        grep -v ">" "$cleanFaFile" | tr 'agct' 'AGCT' | tr -d -c "ACGT" > "$seqFile"; # removes lines with comments and non-nucleotide chars
        echo -e "\033[32mnew sequence: $seqFile \033[0m";
    else
        echo "already exists: $seqFile";
    fi
done
