#!/bin/bash
#
# === DEFAULT VALUES ===========================================================================
#
configJson="../config.json"
#
numHeadersPerDS="$(grep 'DS_numHeaders' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
DS_sizesBase2="$(grep 'DS_sizesBase2' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
DS_sizesBase10="$(grep 'DS_sizesBase10' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
#
rawSequencesPath="$(grep 'rawSequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
sequencesPath="$(grep 'sequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
seqFiles=( $sequencesPath/*.seq );
#
# values represented in bytes
oneBit=$(echo "scale=3; 1/8" | bc);
oneMB_base2=$(echo "2^20" | bc);
oneHundredMB_base2=$(echo "100*2^20" | bc);
oneGB_base2=$(echo "2^30" | bc);
threeGB_base10=$(echo "3*10^9" | bc);
fourGB_base10=$(echo "4*10^9" | bc); # no sequence is greater than this value
#
sizesBytes=( $oneBit $oneMB_base2 $oneHundredMB_base2 $oneGB_base2 $threeGB_base10 $fourGB_base10 );
sizes=("grp1" "grp2" "grp3" "grp4" "grp5");
#
# === MAIN ===========================================================================
#
# add size data to dsToSize (base 2) 
(   printf ":\t:\tRAW:DATA\tBASE:2\tBASE:2\tBASE:2\n"; ( 
    for i in ${!sizesBytes[@]}; do
        ls -la $sequencesPath/*.seq | sed -e 's/\.seq$//' | awk -v m=${sizesBytes[i]} -v M=${sizesBytes[i+1]} -v path="$sequencesPath/" -v grp="${sizes[i]}" '$5 >= m && $5 < M {
            gsub(path,"");
            print $NF"\t"$5":bytes\t"$5/2^10":KB\t"$5/2^20":MB\t"$5/2^30":GB\t"grp
        }';
    done 
) | sort -k2,2n | nl | awk '{$1="DS"$1; print}' ) | column -t | tr ":" " " > "$DS_sizesBase2";
#
# add size data to dsToSize (base 10) 
(   printf ":\t:\tRAW:DATA\tBASE:10\tBASE:10\tBASE:10\n"; ( 
    for i in ${!sizesBytes[@]}; do
        ls -la $sequencesPath/*.seq | sed -e 's/\.seq$//' | awk -v m=${sizesBytes[i]} -v M=${sizesBytes[i+1]} -v path="$sequencesPath/" -v grp="${sizes[i]}" '$5 >= m && $5 < M {
            gsub(path,"");
            print $NF"\t"$5":bytes\t"$5/10^3":KB\t"$5/10^6":MB\t"$5/10^9":GB\t"grp
        }';
    done
) | sort -k2,2n | nl | awk '{$1="DS"$1; print}' ) | column -t | tr ":" " " > "$DS_sizesBase10";
#
# get num of headers of each raw .fa
# find $rawSequencesPath -maxdepth 1 -type f -exec sh -c 'echo -n "$(basename {} | sed "s/_raw\.fa/ /")\t$(grep -o ">" {} | wc -l):headers\n";' \; | column -t | tr ':' ' '> $numHeadersPerDS;
# sort -k2,2n -o $numHeadersPerDS $numHeadersPerDS;
#
# info about sequences can only be obtained after having it
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --view-datasets|--view-ds|-v)
            cat $DS_sizesBase2; echo; cat $DS_sizesBase10;
            exit;
            shift;
            ;;
        *) 
            # ignore any other arguments
            shift
        ;;
    esac
done
#
cat $DS_sizesBase2
