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
POPULATION=100;
#
ALL_SEQUENCES=( $(ls $sequencesPath -S | egrep ".seq$" | sed 's/\.seq$//' | tac) );
SEQUENCES=();
#
seed=1; # JV3 seed interval: [1;599999]
RANDOM=$seed;
#
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
    --sequence|--seq|-s)
      sequence="$2";
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
    --population|-p)
      POPULATION="$2";
      shift 2; 
      ;;
    --seed|-sd)
      seed="$2";
      RANDOM=$seed;
      shift 2;
      ;;
    *) # ignore any other arguments
      shift
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
#echo ${SEQUENCES[7]};
for sequenceName in "${SEQUENCES[@]}"; do
    echo "sequence name: $sequenceName";
    #
    dsX=$(awk '/'$sequenceName'[[:space:]]/ { print $1 }' "$ds_sizesBase2");
    size=$(awk '/'$sequenceName'[[:space:]]/ { print $NF }' "$ds_sizesBase2");
    #
    dsFolder="../${dsX}";
    if [ -d $dsFolder ]; then cp -fr $dsFolder ${dsFolder//DS/bkp_DS}; fi
    rm -fr $dsFolder; # rewrite all generation scripts of dsX...
    mkdir -p $dsFolder;
    #
    outputScript="$dsFolder/g0.sh";
    #
    sequence="$sequencesPath/$sequenceName";
    #
    # PARAMETERS COMMON TO CM AND RM
    NB_I_lst=(1) # (integer {0,1,2}) manages inverted repeats
    #
    # CM PARAMETERS
    # -cm [NB_C]:[NB_D]:[NB_I]:[NB_G]/[NB_S]:[NB_E]:[NB_R]:[NB_A]  
    NB_C_cm_lst=( {1..5} ) # CM size. higher values -> more RAM -> better compression
    NB_D_lst=( 1 2 5 10 20 50 100 200 500 1000 2000 ) # (integer [1;5000]) alpha=1/NB_D => parameter estimator
    NB_G_cm_lst=(0.9) # (real [0;1)) gamma; decayment forgetting factor of CM
    NB_S_lst=( {0..6} ) # (integer [0;20]) max number of substitutions allowed in a STCM (substitution tolerant CM)
    NB_R_cm_lst=( 0 1 ) # (integer {0,1}) checks if inverted repeats are used in a tolerant model (stcm?)
    NB_E_lst=( 1 2 5 10 20 50 100 ) # ! (integer [1;5000]) denominator that builds alpha on STCM
    NB_A_lst=($(seq 0 0.1 0.9)) # (real [0;1)) gamma (decayment forgetting factor of the STCM)
    #
    # RM PARAMETERS
    # -rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y}
    NB_C_rm_lst=(12 13) # RM size. higher values -> more RAM -> better compression
    NB_R_rm_lst=( 1 2 5 10 20 50 100 200 ) # (integer [1;10000]) max num of repeat models
    NB_B_lst=($(seq 0.5 0.1 0.9)) # (real (0;1]) beta. discards or keeps a repeat model
    NB_L_lst=( {4..9} ) # (integer (1;20]) limit threshold; has dependency with NB_B
    NB_G_rm_lst=(0.7) # (real [0;1)) gamma; decayment forgetting factor
    NB_W_lst=(0.06) # (real (0;1)) initial weight for repeat classes
    NB_Y_lst=(2) # (integer {0}, [1;50]) max cache size
    #
    # write stochastically generated commands
    for ((i=1; i<=POPULATION; i++)); do
      min_cms=1;
      max_cms=3;
      #
      # can go from 1 to 5
      num_cms=$((RANDOM % (max_cms - min_cms + 1) + min_cms));
      #
      CM="";
      for ((j=1; j<=num_cms; j++)); do
        # randomly chosen cm parameter values -cm 1:1:0:0.9/0:0:0:0
        NB_C=${NB_C_cm_lst[$((RANDOM % ${#NB_C_cm_lst[@]}))]};
        NB_D=${NB_D_lst[$((RANDOM % ${#NB_D_lst[@]}))]}; 
        NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]}; 
        NB_G=${NB_G_cm_lst[$((RANDOM % ${#NB_G_cm_lst[@]}))]};
        NB_S=${NB_S_lst[$((RANDOM % ${#NB_S_lst[@]}))]};
        NB_R=${NB_R_cm_lst[$((RANDOM % ${#NB_R_cm_lst[@]}))]};
        NB_E=${NB_E_lst[$((RANDOM % ${#NB_E_lst[@]}))]};
        NB_A=${NB_A_lst[$((RANDOM % ${#NB_A_lst[@]}))]};
        #
        CM+="-cm ${NB_C}:${NB_D}:${NB_I}:${NB_G}/${NB_S}:${NB_E}:${NB_R}:${NB_A} ";
      done
      #
      min_rms=0;
      max_rms=1;
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
        NB_I=${NB_I_lst[$((RANDOM % ${#NB_I_lst[@]}))]};
        NB_W=${NB_W_lst[$((RANDOM % ${#NB_W_lst[@]}))]};
        NB_Y=${NB_Y_lst[$((RANDOM % ${#NB_Y_lst[@]}))]};
        #
        RM+="-rm ${NB_R}:${NB_C}:${NB_B}:${NB_L}:${NB_G}:${NB_I}:${NB_W}:${NB_Y} ";
      done
      #
      printf "${jv3Path}JARVIS3 $CM$RM$sequence.seq \n" >> $outputScript;
      seed=$((seed+10));
    done
    #
    echo "$POPULATION cmds have been written to $outputScript";
    chmod +x $outputScript;
    echo "$outputScript is executable";
    echo "--------------------------------------------------";
    #
done