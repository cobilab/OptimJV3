#!/bin/bash
#
# === FUNCTIONS ==========================================================================
#
function SHOW_HELP() {
  echo " -------------------------------------------------------";
  echo "                                                        ";
  echo " OptimJV3 - optimize JARVIS3 CM and RM parameters       ";
  echo "                                                        ";
  echo " Program options ---------------------------------------";
  echo "                                                        ";
  echo " --help|-h.....................................Show this";
  echo " --view-datasets|--view-ds|-v....View sequences and size"; 
  echo "                                                 of each";
  echo "--sequence|--seq|-s..........Select sequence by its name";
  echo "--sequence-group|--seq-grp|-sg.Select group of sequences";
  echo "                                           by their size";
  echo "--dataset|-ds......Select sequence by its dataset number";
  echo "--dataset-range|--dsrange|--drange|-dr............Select";
  echo "                   sequences by range of dataset numbers";
  echo "--seed|-sd..............Pseudo-random seed. Value: $seed";
  echo "                                                        ";
  echo " -------------------------------------------------------";
}
#
function FIX_SEQUENCE_NAME() {
    sequence="$1"
    sequence=$(echo $sequence | sed 's/.mfasta//g; s/.fasta//g; s/.mfa//g; s/.fa//g; s/.seq//g')
    #
    if [ "${sequence^^}" == "CY" ]; then 
        sequence="CY"
    elif [ "${sequence^^}" == "CASSAVA" ]; then 
        sequence="TME204.HiFi_HiC.haplotig1"
    elif [ "${sequence^^}" == "HUMAN" ]; then
        sequence="chm13v2.0"
    fi
}
#
function SAVE_SEED() {
    seedAndSiFile="$gaFolder/seed_and_si.txt"
    printf "$seed\t$si\n" > $seedAndSiFile
}
#
function GET_SEED() {
    seedAndSiFile="$gaFolder/seed_and_si.txt"
    if [ -f $seedAndSiFile ]; then
        [ -z "$seed" ] && seed=$(awk '{print $1}' $seedAndSiFile) && RANDOM=$seed
        [ -z "$si" ] && si=$(awk '{print $2}' $seedAndSiFile)
    else 
        [ -z "$seed" ] && seed=1 && RANDOM=$seed
        [ -z "$si" ] && si=10
        printf "$seed\t$si\n" > $seedAndSiFile
    fi
}
#
function DEFINE_PARAM_RANGES() {
  if $kbi; then # knowledge-based initialization
    #
    min_cms=1;
    max_cms=5;
    min_rms=1;
    max_rms=4;
    #
    # CM PARAMETERS
    # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
    NB_C_cm_lst=( {1..13} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( 1 2 5 10 20 50 100 200 500 1000 2000 ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_I_cm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_G_cm_lst=( $(seq 0.05 0.05 0.95) ) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..6} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant ga (stcm?)
    NB_E_lst=( 1 2 5 10 20 50 100 ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_A_lst=($(seq 0.1 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of repeat gas
    NB_C_rm_lst=(12 13 14) # RM size. higher values -> more RAM -> better compression
    NB_B_lst=($(seq 0.05 0.05 0.95)) # (real (0;1]) beta. discards or keeps a repeat ga
    NB_L_lst=( {1..14} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=( $(seq 0.05 0.05 0.95) ) # (real [0;1)) gamma; decayment forgetting factor
    NB_I_rm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_W_lst=( $(seq 0.01 0.05 0.99) ) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=( $(seq 0 1 5) ) # (integer {0}, [1;50]) max cache size
  else
    #
    min_cms=1;
    max_cms=5;
    min_rms=1;
    max_rms=4;
    #
    # CM PARAMETERS
    # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
    NB_C_cm_lst=( {1..12} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( {1..5000} ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_I_cm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_G_cm_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..20} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant ga (stcm?)
    NB_E_lst=( {1..5000} ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_A_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_R_rm_lst=( {1..500} ) # (integer [1;10000]) max num of repeat gas
    NB_C_rm_lst=( {1..13} ) # RM size. higher values -> more RAM -> better compression
    NB_B_lst=($(seq 0.01 0.01 0.99)) # (real (0;1]) beta. discards or keeps a repeat ga
    NB_L_lst=( {2..20} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=( $(seq 0 0.01 0.99) ) # (real [0;1)) gamma; decayment forgetting factor
    NB_I_rm_lst=(0 1 2) # (integer {0,1,2}) manages inverted repeats
    NB_W_lst=( $(seq 0.01 0.01 0.99) ) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=( $(seq 0 1 5) ) # (integer {0}, [1;50]) max cache size
  fi
}
#
# === DEFAULT VALUES ===========================================================================
#
sequencesPath="../../sequences";
jv3Path="../jv3/";
#
ds_sizesBase2="../../DS_sizesBase2.tsv";
ds_sizesBase10="../../DS_sizesBase10.tsv";
#
sizes=("grp1" "grp2" "grp3" "grp4" "grp5"); # sequence size groups
#
POPULATION_SIZE=100;
#
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
#
# knowledge-based initialization
kbi=false
#
ga="ga";
#
#== PARSING ===========================================================================
#
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --help|-h)
      SHOW_HELP;
      exit;
      shift;
      ;;
    --view-datasets|--view-ds|-v)
      cat $ds_sizesBase2; echo; cat $ds_sizesBase10;
      exit;
      shift;
      ;;
    --genetic-algorithm|--algorithm|--ga|-ga|-a)
      ga="$2";
      shift 2; 
      ;;
    --sequence|--seq|-s)
      sequence="$2";
      FIX_SEQUENCE_NAME "$sequence"
      #
      SEQUENCES+=( "$sequence" );
      shift 2; 
      ;;
    --sequence-group|--sequence-grp|--seq-group|--seq-grp|-sg)
      size="$2";
      SEQUENCES+=( $(awk '/[[:space:]]'$size'/ { print $2 }' "$ds_sizesBase2") );
      shift 2; 
      ;;
    --dataset|-ds)
      dsnum=$(echo "$2" | tr -d "dsDS");
      SEQUENCES+=( "$(awk '/DS'$dsnum'[[:space:]]/{print $2}' "$ds_sizesBase2")" );
      shift 2;
      ;;
    --dataset-range|--dsrange|--drange|-dr)
      input=( $(echo "$2" | sed 's/[:/]/ /g') );
      sortedInput=( $(printf "%s\n" ${input[@]} | sort -n ) );
      dsmin="${sortedInput[0]}";
      dsmax="${sortedInput[1]}";
      SEQUENCES+=( $(awk -v m=$dsmin -v M=$dsmax 'NR>=1+m && NR <=1+M {print $2}' "$ds_sizesBase2") );
      shift 2;
      ;;
    --population-size|--population|--psize|-ps)
      POPULATION_SIZE="$2";
      shift 2;
      ;;
    --knowledge-based-initialization|-kbi)
      kbi=true
      shift
      ;;
    --min-cm|--m-cm|-mCM)
      min_cms="$2";
      shift 2;
      ;;
    --max-cm|--M-cm|-MCM)
      max_cms="$2";
      shift 2;
      ;;
    --min-rm|--m-rm|-mRM)
      min_rms="$2";
      shift 2;
      ;;
    --max-rm|--M-rm|-MRM)
      max_rms="$2";
      shift 2; 
      ;;
    --learning-rate|-lr) 
      # 0 value turns the NN off
      lr="-lr $2 ";
      shift 2;
      ;; 
    --hidden-size|-hs) 
      # hidden size of the NN
      hs="-hs $2 ";
      shift 2;
      ;; 
    --seed|-sd)
      seed="$2";
      RANDOM=$seed;
      shift 2;
      ;;
    --seed-increment|-si)
      si="$2";
      shift 2;
      ;;
    *) # ignore any other arguments
      echo "Invalid option: $1"
      exit 1;
      ;;
  esac
done
#
if [ ${#SEQUENCES[@]} -eq 0 ]; then
  SEQUENCES=( "${ALL_SEQUENCES[@]}" );
fi
#
# === MAIN ===========================================================================
#
for sequenceName in "${SEQUENCES[@]}"; do
    sequence="$sequencesPath/$sequenceName";
    #
    dsX=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    size=$(awk '/'$sequenceName'[[:space:]]/ { print $NF }' "$ds_sizesBase2");
    #
    dsFolder="../${dsX}";
    mkdir -p $dsFolder;
    #
    # if GA folder is not empty, it becomes backup
    gaFolder="$dsFolder/$ga"
    if [ ! -d $(ll $gaFolder 2> /dev/null) ]; then 
        mv $gaFolder ${gaFolder}_bkp
    fi
    mkdir -p $gaFolder
    GET_SEED
    #
    outputScript="$gaFolder/g1.sh";
    #
    DEFINE_PARAM_RANGES;
    #
    # write stochastically generated commands
    ( for ((i=1; i<=POPULATION_SIZE; i++)); do
      #
      # can go from 1 to 5
      num_cms=$((RANDOM % (max_cms - min_cms + 1) + min_cms));
      #
      CM="";
      for ((j=1; j<=num_cms; j++)); do
        # randomly chosen cm parameter values -cm 1:1:0:0.9/0:0:0:0
        NB_C=${NB_C_cm_lst[$((RANDOM % ${#NB_C_cm_lst[@]}))]};
        NB_D=${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}; 
        NB_I=${NB_I_cm_lst[$((RANDOM % ${#NB_I_cm_lst[@]}))]}; 
        NB_G=${NB_G_cm_lst[$((RANDOM % ${#NB_G_cm_lst[@]}))]};
        NB_S=${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]};
        NB_R=${NB_R_cm_lst[$((RANDOM % ${#NB_R_cm_lst[@]}))]};
        NB_E=${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]};
        NB_A=${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]};
        #
        CM+="-cm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_E}:${NB_R}:${NB_A} ";
      done
      #
      # can go from 0 to 2
      num_rms=$((RANDOM % (max_rms - min_rms + 1) + min_rms));
      #
      RM="";
      for ((j=1; j<=num_rms; j++)); do
        # randomly chosen rm parameter values
        NB_R=${NB_R_rm_lst[$((RANDOM % ${#NB_R_rm_lst[@]}))]};
        NB_C=${NB_C_rm_lst[$((RANDOM % ${#NB_C_rm_lst[@]}))]}; 
        NB_B=${NB_B_lst[$((RANDOM % ${#NB_B_lst[@]}))]}; 
        NB_L=${NB_L_lst[$((RANDOM % ${#NB_L_lst[@]}))]};
        NB_G=${NB_G_rm_lst[$((RANDOM % ${#NB_G_rm_lst[@]}))]}; 
        NB_I=${NB_I_rm_lst[$((RANDOM % ${#NB_I_rm_lst[@]}))]};
        NB_W=${NB_W_lst[$((RANDOM % ${#NB_W_lst[@]}))]};
        NB_Y=${NB_Y_lst[$((RANDOM % ${#NB_Y_lst[@]}))]};
        #
        RM+="-rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y} ";
      done
      #
      flags="$lr$hs$CM$RM$mRM"
      printf "${jv3Path}JARVIS3 -v $flags$sequence.seq \n";
    done ) > $outputScript;
    #
    chmod +x $outputScript;
    #
    echo "sequence name: $sequenceName";
    echo "$POPULATION_SIZE cmds have been written to $outputScript";
    echo "$outputScript is executable";
    echo "--------------------------------------------------";
    #
    seed=$((seed+si)) && SAVE_SEED
done
