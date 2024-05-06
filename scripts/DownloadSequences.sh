#!/bin/bash
#
binPath="../bin";
#
rawSequencesPath="../../sequences_raw";
mkdir -p $rawSequencesPath;
#
urls=(
   # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102253/Coding_Sequences_AldGig_1.0.fa" # 4.45GB
   # "https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/analysis_set/chm13v2.0.fa.gz" # DS28 - human reference genome # ~3GB, broken link
   # "https://ftp.ncbi.nlm.nih.gov/refseq/H_sapiens/annotation/GRCh38_latest/refseq_identifiers/GRCh38_latest_genomic.fna.gz" # human reference genome # ~3GB
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102252/SI_Tiger_assembly.fasta" # DS27 - 2.39GB, RepeatMasker out file containing the annotation for repetitive sequences for PanTigT.SI genome assembly, [DOI] 10.5524/102252, http://gigadb.org/dataset/102252
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102252/Bengal_Tiger_Machali.fasta" # DS26 - 2.27GB, fasta file for PanTigT.MC genome assembly (tiger), [DOI] 10.5524/102252, http://gigadb.org/dataset/102252
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102199/GCA_004024665.1_LemCat_v1_BIUU_genomic.fna" # DS25 - 2.22GB, LemCat_v1_BIUU assembly (illumina) (ring-tailed lemur), [DOI] 10.5524/102199, http://gigadb.org/dataset/102199
    #
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102191/Pseudobrama_simoni.genome.fa" # DS24 - 886.11MB, The genome sequence of Pseudobrama_simoni (cyprinid fish), [DOI] 10.5524/102191, http://gigadb.org/dataset/102191
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102192/Rhodeus_ocellatus.genome.fa" # DS23 -860.71MB, The genome sequence of Rhodeus_ocellatus (rosy bitterling), [DOI] 10.5524/102192, http://gigadb.org/dataset/102192
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102188/Naso_vlamingii.genome.fa" # DS22 - 821.29MB, The genome sequence of Naso_vlamingii (bignose unicornfish/zebra unicornfish), [DOI] 10.5524/102188, http://gigadb.org/dataset/102188
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102193/00_Assembly_Fasta/haplotigs/TME204.HiFi_HiC.haplotig1.fa" # DS21 - 727.09MB, CASSAVA
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102193/00_Assembly_Fasta/haplotigs/TME204.HiFi_HiC.haplotig2.fa" # DS20 - 673.62MB
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102187/Chaetodon_trifasciatus.genome.fa" # DS19 - 636.91MB, The genome sequence of Chaetodon_trifasciatus (Melon Butterflyfish), [DOI] 10.5524/102187, http://gigadb.org/dataset/102187
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102189/Chelmon_rostratus.genome.fa" # DS18 - 609.48MB, The genome sequence of Chelmon_rostratus (copperband butterflyfish/beaked coral fish), [DOI] 10.5524/102189, http://gigadb.org/dataset/102189
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102190/Helostoma_temminckii.genome.fa" # DS17 - 605.25MB, The genome sequence of Helostoma_temminckii (kissing fish), [DOI] 10.5524/102190, http://gigadb.org/dataset/102190
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102239/131021_Filtered_Dendrobium_mutatnt-assembly.fasta.gz" # DS16 - 202.24MB (.gz), De novo MaSuRCA assembled contigs of Dendrobium Emma White genome (flower), [DOI] 10.5524/102239, http://gigadb.org/dataset/102239
    #
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102198/ensete_glaucum.evm.cds.fna" # DS15 - 40.21MB, Coding sequences of predicted genes of Ensete glaucum genome (plant known as snow banana), [DOI] 10.5524/102198, http://gigadb.org/dataset/102198
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102173/Spheniscus_magellanicus.cds.v1.fa" # DS14 - 23.49MB, coding gene nucleotide sequences (Magellanic penguin), [DOI] 10.5524/102173, http://gigadb.org/dataset/102173
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102171/Eudyptes_moseleyi.cds.v1.fa" # DS13 - 23.34MB, coding gene nucleotide sequences (Northern Rockhopper penguin), [DOI] 10.5524/102171, http://gigadb.org/dataset/102171
   # CY.seq # DS12 - 22.67MB, xy human chromosome
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102172/Megadyptes_antipodes_antipodes.cds.v1.fa" # DS11 - 22.28MB, coding gene nucleotide sequences (Yellow-eyed penguin), [DOI] 10.5524/102172, http://gigadb.org/dataset/102172 
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102174/Spheniscus_demersus.cds.v1.fa" # DS10 - 21.87MB, coding gene nucleotide sequences (african penguin), [DOI] 10.5524/102174, http://gigadb.org/dataset/102174
    #
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102256/SARS-CoV-Hun-1.fasta" # 29.61KB, Assembled genome sequence of the SARS-CoV-Hun-1 variant, [DOI] 10.5524/102256, http://gigadb.org/dataset/102256
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102230/eubas_hfib_1.fasta" # 24.67KB, Complete h-fibroin (with intron) nt sequence of Eubasilissa regina (caddisfly), [DOI] 10.5524/102230, http://gigadb.org/dataset/102230
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102230/eubas_hfib_1.cds.fasta" # 24.58KB, Protein coding h-fibroin (without intron) nt sequence of Eubasilissa regina (caddisfly), [DOI] 10.5524/102230, http://gigadb.org/dataset/102230
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102231/plodia_hfib_flanking.fa" # 16.49KB, Genome sequence of h-fibroin plus flanking regions (1,000 bp each side) of Plodia interpunctella (bug), [DOI] 10.5524/102231, http://gigadb.org/dataset/102231
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102253/Aldabrachelys_gigantea_mitochondrial_genome.fasta" # 16.55KB, The mitochondrial of the Aldabrachelys gigantea (giant tortoise), [DOI] 10.5524/102253, http://gigadb.org/dataset/102253
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102194/mt_genome_CM029732.fa" # 15.06KB, Pollicipes pollicipes mitochondrial genome assembly (percebes), [DOI] 10.5524/102194, http://gigadb.org/dataset/102194
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/100001_101000/100185/reference_sequences/lactobacillus_gasseri.fasta" # 1.70KB, reference sequence of Lactobacillus gasseri bacteria, [DOI] 10.5524/100185, http://gigadb.org/dataset/100185
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/100001_101000/100185/reference_sequences/staphylococcus_epidermidis.fasta" # 1.68KB, reference sequence of staphylococcus epidermidis bacteria, [DOI] 10.5524/100185, http://gigadb.org/dataset/100185
   "https://ftp.cngb.org/pub/gigadb/pub/10.5524/100001_101000/100185/reference_sequences/escherichia_coli.fasta" # 1.65KB, reference sequence of E. coli bacteria, [DOI] 10.5524/100185, http://gigadb.org/dataset/100185
)
#
# reverse urls array so that smaller sequence files are downloaded first
urls_rev=();
for (( i=${#urls[@]}-1; i>=0; i-- )) ; do
   urls_rev+=("${urls[i]}");
done
#
printf "%s\n" ${urls_rev[@]}
#
#
# === Download rawFiles ===========================================================================
#
printf "downloading ${#urls_rev[@]} sequence files...\n"
for url in "${urls_rev[@]}"; do
    #
    # gets raw filename by: 
    #     spliting in "/" and getting the last element,
    #     replacing all "-" for "_"; 
    #     replacing .fa, .fna or .fasta for _raw.fa
    rawFile=$(echo $url | rev | cut -d'/' -f1 | rev | sed 's/-/_/g' | sed 's/\.fa\|\.fna\|\.fasta/_raw.fa/')
    #
    if [[ ! -f "$rawSequencesPath/$rawFile" ]]; then 
        echo "downloading $origFile file..."
        wget -c $url -O "$rawSequencesPath/$rawFile"
    else
        # no need to download a file that already exists
        echo "$rawFile has been previously downloaded"
    fi
    #
    # unzip file if it ends with .gz
    if [[ "$rawSequencesPath/$rawFile" == *.gz ]]; then
        echo "$rawFile is being gunzipped..."
        gunzip "$rawSequencesPath/$rawFile"
    fi
done
