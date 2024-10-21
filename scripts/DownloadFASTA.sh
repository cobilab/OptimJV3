#!/bin/bash
#
function SHOW_HELP() {
  echo " -------------------------------------------------------";
  echo "                                                        ";
  echo " CompressSequences - JARIVS3 Optimization Benchmark     ";
  echo " Download FASTA files script                            ";
  echo "                                                        ";
  echo " Program options ---------------------------------------";
  echo "                                                        ";
  echo " --help|-h.....................................Show this";
  echo " -id........................Download sequence by NCBI id"; 
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
function FIX_NAME() {
    [[ $rawFile=="NC_000024"* ]] && rawFile="CY_raw.fa"
}
#
# ===========================================================================
#
defaultUrls=(
    "https://s3-us-west-2.amazonaws.com/human-pangenomics/T2T/CHM13/assemblies/analysis_set/chm13v2.0.fa.gz" # complete human genome (~3GB)

    # # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102193/00_Assembly_Fasta/haplotigs/TME204.HiFi_HiC.haplotig1.fa" # CASSAVA, 727.09MB
    # # "https://ftp.cngb.org/pub/gigadb/pub/10.5524/102001_103000/102193/00_Assembly_Fasta/haplotigs/TME204.HiFi_HiC.haplotig2.fa" # 673.62MB

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_058373.1&rettype=fasta&retmode=text" # Felis catus isolate Fca126 chromosome B3, F.catus_Fca126_mat1.0, whole genome shotgun sequence (144MB)

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000001.11&rettype=fasta&retmode=text" # complete chromosome 1 from Homo sapiens
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000008.11&rettype=fasta&retmode=text" # complete chromosome 8 from Homo sapiens
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000021.9&rettype=fasta&retmode=text" # complete chromosome 21 from Homo sapiens

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000024.1&rettype=fasta&retmode=text" # CY

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000908.2&rettype=fasta&retmode=text" # Mycoplasmoides genitalium G37, complete sequence

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=BA000046.3&rettype=fasta&retmode=text" # Pan troglodytes DNA, chromosome 22, complete sequence (32 MB)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_073246.2&rettype=fasta&retmode=text" # Gorilla gorilla gorilla isolate KB3781 chromosome 22, NHGRI_mGorGor1-v2.0_pri, whole genome shotgun sequence (40MB)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_072005.2&rettype=fasta&retmode=text" # Pongo abelii isolate AG06213 chromosome 20, NHGRI_mPonAbe1-v2.0_pri, whole genome shotgun sequence (63M)

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_004461.1&rettype=fasta&retmode=text" # Staphylococcus epidermidis ATCC 12228, complete sequence (staphylococcus_epidermidis_raw.fa) (2,4M)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=CM029732.1&rettype=fasta&retmode=text" # Pollicipes pollicipes isolate AB1234 mitochondrion, complete sequence, whole genome shotgun sequence (mt_genome_CM029732_raw.fa) (15KB)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=OM812693.1&rettype=fasta&retmode=text" # covid (SARS_CoV_Hun_1_raw.fa) (30K)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=CM047480.1&rettype=fasta&retmode=text" # Aldabrachelys gigantea (290M)

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=KT868810.1&rettype=fasta&retmode=text" # Cutavirus strain BR-283 NS1 gene, partial cds; and putative VP1, hypothetical protein, VP2, and hypothetical protein genes, complete cds (4,3K)

    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_000898.1&rettype=fasta&retmode=text" # Human herpesvirus 6B, complete genome (161K)
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=NC_001664.4&rettype=fasta&retmode=text" # Human betaherpesvirus 6A, variant A DNA, complete virion genome, isolate U1102 (158K)
)
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h)
        SHOW_HELP
        shift 2; 
        ;;
    -id)
        id="$2"
        urls+=("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=${id}&rettype=fasta&retmode=text")
        shift 2; 
        ;;
    *) 
        echo "Invalid option: $1"
        exit 1;
        ;;
    esac
done
#
# default urls are only considered if no ncbi id is defined by user
[ "${#urls[@]}" -eq 0 ] && urls=( "${defaultUrls[@]}" )
#
configJson="../config.json"
rawSequencesPath="$(grep 'rawSequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
mkdir -p $rawSequencesPath;
#
# === Download rawFiles ===========================================================================
#
printf "downloading ${#urls[@]} sequence files...\n"
for url in "${urls[@]}"; do
    #
    if [[ "$url" == *"eutils.ncbi.nlm.nih.gov"* ]]; then 
        rawFile="$(echo "$url" | awk -F'&id' '{print $2}' | awk -F'&' '{print $1}' | tr -d '\\=' | tr '.' '_')_raw.fa"
    else
        rawFile="$(echo $url | rev | cut -d'/' -f1 | rev | sed 's/-/_/g' | sed 's/\.fa\|\.fna\|\.fasta/_raw.fa/')"
        FIX_NAME
    fi
    #
    if [[ ! -f "$rawSequencesPath/$rawFile" ]]; then 
        echo -e "\033[32mdownloading $rawFile file... \033[0m"
        curl $url -o "$rawSequencesPath/$rawFile"
    else
        # no need to download a file that already exists
        echo "$rawFile has been previously downloaded"
    fi
    #
    # unzip file if it ends with .gz
    if [[ "$rawSequencesPath/$rawFile" == *.gz ]]; then
        echo -e "$\033[32mrawFile is being gunzipped... \033[0m"
        gunzip "$rawSequencesPath/$rawFile"
    fi
done
