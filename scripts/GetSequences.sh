#!/bin/bash

binPath="../bin";

sequencesPath="../../sequences_raw";
mkdir -p $sequencesPath;

urls=(
    # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102253/Coding_Sequences_AldGig_1.0.fa" # 4.45GB
    # "https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/analysis_set/chm13v2.0.fa" # human reference genome # ~3GB, broken link
    # "https://ftp.ncbi.nlm.nih.gov/refseq/H_sapiens/annotation/GRCh38_latest/refseq_identifiers/GRCh38_latest_genomic.fna.gz" # human reference genome # ~3GB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102252/SI_Tiger_assembly.fasta" # 2.39GB, RepeatMasker out file containing the annotation for repetitive sequences for PanTigT.SI genome assembly, [DOI] 10.5524/102252, http://gigadb.org/dataset/102252
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102252/Bengal_Tiger_Machali.fasta" # 2.27GB, fasta file for PanTigT.MC genome assembly (tiger), [DOI] 10.5524/102252, http://gigadb.org/dataset/102252
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102199/GCA_004024665.1_LemCat_v1_BIUU_genomic.fna" # DS23 - 2.22GB, LemCat_v1_BIUU assembly (illumina) (ring-tailed lemur), [DOI] 10.5524/102199, http://gigadb.org/dataset/102199

    # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102199/hg38.fa.gz" # 938.09MB
    # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102199/gorGor6.fa.gz" # 903.79MB
    # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102199/calJac4.fa.gz" # 887.99MB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102191/Pseudobrama_simoni.genome.fa" # DS22 - 886.11MB, The genome sequence of Pseudobrama_simoni (cyprinid fish), [DOI] 10.5524/102191, http://gigadb.org/dataset/102191
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102192/Rhodeus_ocellatus.genome.fa" # DS21 -860.71MB, The genome sequence of Rhodeus_ocellatus (rosy bitterling), [DOI] 10.5524/102192, http://gigadb.org/dataset/102192
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102188/Naso_vlamingii.genome.fa" # DS20 - 821.29MB, The genome sequence of Naso_vlamingii (bignose unicornfish/zebra unicornfish), [DOI] 10.5524/102188, http://gigadb.org/dataset/102188
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102193/00_Assembly_Fasta/haplotigs/TME204.HiFi_HiC.haplotig1.fa" # DS19 - 727.09MB, CASSAVA
    # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102199/Mmur_3.0.fa.gz" # 720.14MB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102193/00_Assembly_Fasta/haplotigs/TME204.HiFi_HiC.haplotig2.fa" # DS18 - 673.62MB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102187/Chaetodon_trifasciatus.genome.fa" # DS17 - 636.91MB, The genome sequence of Chaetodon_trifasciatus (Melon Butterflyfish), [DOI] 10.5524/102187, http://gigadb.org/dataset/102187
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102189/Chelmon_rostratus.genome.fa" # DS16 - 609.48MB, The genome sequence of Chelmon_rostratus (copperband butterflyfish/beaked coral fish), [DOI] 10.5524/102189, http://gigadb.org/dataset/102189
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102190/Helostoma_temminckii.genome.fa" # DS15 - 605.25MB, The genome sequence of Helostoma_temminckii (kissing fish), [DOI] 10.5524/102190, http://gigadb.org/dataset/102190

    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102198/ensete_glaucum.evm.cds.fna" # 40.21MB, Coding sequences of predicted genes of Ensete glaucum genome (plant known as snow banana), [DOI] 10.5524/102198, http://gigadb.org/dataset/102198
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102173/Spheniscus_magellanicus.cds.v1.fa" # 23.49MB, coding gene nucleotide sequences (Magellanic penguin), [DOI] 10.5524/102173, http://gigadb.org/dataset/102173
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102171/Eudyptes_moseleyi.cds.v1.fa" # 23.34MB, coding gene nucleotide sequences (Northern Rockhopper penguin), [DOI] 10.5524/102171, http://gigadb.org/dataset/102171
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102172/Megadyptes_antipodes_antipodes.cds.v1.fa" # 22.28MB, coding gene nucleotide sequences (Yellow-eyed penguin), [DOI] 10.5524/102172, http://gigadb.org/dataset/102172 
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102174/Spheniscus_demersus.cds.v1.fa" # DS10 - 21.87MB, coding gene nucleotide sequences (african penguin), [DOI] 10.5524/102174, http://gigadb.org/dataset/102174 

    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102012/RL0949_chloroplast.fa" # 157.91KB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/101001_102000/101111/RL0048_chloroplast.fa" # 154.2KB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102011/RL0948_chloroplast.fa" # 153.45KB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102130/RL1067_chloroplast.fa" # 150.17KB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/101001_102000/101120/RL0057_chloroplast.fa" # 135.7KB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102150/RL1087_chloroplast.fa" # 134.88KB
    "https://raw.githubusercontent.com/plotly/datasets/master/Dash_Bio/Genetic/COVID_sequence.fasta" # 29.7KB
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102253/Aldabrachelys_gigantea_mitochondrial_genome.fasta" # 16.55KB, The mitochondrial of the Aldabrachelys gigantea (giant tortoise), [DOI] 10.5524/102253, http://gigadb.org/dataset/102253
    "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102194/mt_genome_CM029732.fa" # 15.06KB, Pollicipes pollicipes mitochondrial genome assembly (percebes), [DOI] 10.5524/102194, http://gigadb.org/dataset/102194
)

# reverse urls array so that smaller sequence files are downloaded first
urls_rev=();
for (( i=${#urls[@]}-1; i>=0; i-- )) ; do
    urls_rev+=("${urls[i]}");
done

printf "%s\n" ${urls_rev[@]}

#
# === Download rawFiles ===========================================================================
#
printf "downloading ${#urls_rev[@]} sequence files...\n"
for url in "${urls_rev[@]}"; do
    # gets filename by spliting in "/" and getting the last element
    rawFile=$(echo $url | rev | cut -d'/' -f1 | rev | sed 's/\.fa\|\.fna\|\.fasta/_raw.fa/')
    origFile="${rawFile//_raw/}"

    if [[ ! -f "$sequencesPath/$origFile" ]]; then 
        echo "downloading $origFile file..."
        wget -c $url -O "$sequencesPath/$rawFile"
    else
        # no need to download a file that already exists
        echo "$origFile has been previously downloaded"
    fi
done

# # is each raw file a multifasta file or not?
find $sequencesPath -maxdepth 1 -type f -exec sh -c 'echo -n "{} has how many headers? "; grep -o "<" {} | wc -l' \; > "../../sequences_info.txt"


# rawFiles=( $sequencesPath/*_raw.fa )

#
# === _raw.fa files ---> clean .fa and .seq files ===========================================================================
#
# printf "\n*_raw.fa ---cleaning...---> *.fa\n" # preprocesses each fasta file into its respective clean files
# for rawFile in "${rawFiles[@]}"; do
#     cleanFaFile=${rawFile/_raw.fa/.fa};

#     if [[ ! -f $sequencesPath/$cleanFaFile ]]; then
#         # in multifasta files, this cleaning implies removing all of their headers...
#         $binPath/gto_fasta_to_seq < $rawFile | tr 'agct' 'AGCT' | tr -d -c "AGCT" | $binPath/gto_fasta_from_seq -n x -l 80 > $cleanFaFile
#         echo "$cleanFaFile created with success"
#     else
#         echo "$cleanFaFile has been previously created"
#     fi

#     rm -fr $rawFile
# done

# printf "\n*.fa ------> *.seq\n" # preprocesses each clean fasta file into its respective sequence
# cleanFiles=( $sequencesPath/*.fa )
# for cleanFile in "${cleanFiles[@]}"; do
#     seqFile=$(echo $cleanFile | sed 's/.fa/.seq/g');
#     if [[ ! -f $sequencesPath/$seqFile ]]; then
#         cat "$cleanFile" | grep -v ">" | tr 'agct' 'AGCT' | tr -d -c "ACGT" > "$seqFile" # removes lines with comments and non-nucleotide chars
#         echo "$seqFile created with success"
#     else
#         echo "$seqFile has been previously created"
#     fi
# done
