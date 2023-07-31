#rm sequence_model.fasta
#rm shuffled.fasta.gz
#rm ordered_sequence_model_size.fasta.gz
#rm ordered_sequence_model_AT.fasta.gz
#rm ordered_sequence_model_CG.fasta.gz
#rm ordered_shuffled_size.fasta.gz
#rm ordered_shuffled_AT.fasta.gz
#rm ordered_shuffled_CG.fasta.gz
#rm sort_fanalysis.fasta.gz
#rm sort.fa.gz
#rm sequence_model.fasta.gz

# Define the lowest sequence size to be considered
LOWEST_SIZE=100;

# Define the increment factor to be used on sequence sizes
INCREMENT_FACTOR=2;

# Define the seed range
SEED_RANGE=10;

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lowest-size|-l)
      LOWEST_SIZE=$2
      shift
      ;;
    --increment-factor|-i)
      INCREMENT_FACTOR=$2
      shift
      ;;
    --seed-range|-s)
      SEED_RANGE=$2
      shift
      ;;
    *)
      echo "Invalid option: $1"
      exit 1;
      ;;
  esac
  shift
done


OUT_FILE="alcorSeq.mfa";

#read -p "Define the number of different sequences sizes to be considered: " SIZE_NUMBER

#echo "The first $SEED_RANGE prime numbers  are: "
declare -a seed_arr=()
declare -a size_arr=()

rm -fr alcorSeq*.*;

m=2
while [  ${#seed_arr[@]}  -lt $SEED_RANGE ]
do
    i=2
    flag=0
    while [ $i -le `expr $m / 2` ]
    do
        if [ `expr $m % $i` -eq 0 ]
        then
            flag=1
            break
        fi
        i=`expr $i + 1`
    done
    if [ $flag -eq 0 ]
    then
        #echo $m
        seed_arr+=($m)
        #echo ${#seed_arr[@]}
    fi
    m=`expr $m + 1`
done

for((i=0;i<${#seed_arr[@]}; i++ ))
do
    echo ${seed_arr[$i]} #> prime_numbers.txt
done

INCREMENT=0
#for x in {1..$SIZE_NUMBER}
size=$((LOWEST_SIZE))
for((i=1;i<=$SEED_RANGE; i++ ))
do
    j=$(($i-1))
    size=$(($size+$INCREMENT))
    echo $
    # echo $size
    #echo ${seed_arr[i]}
    seed=${seed_arr[$j]}
    size_arr+=($size)
    INCREMENT=$(($INCREMENT_FACTOR*$LOWEST_SIZE))
    #echo $seed
    #echo $size
    ./AlcoR simulation -rs  $size:0:$seed:0:0:0 > alcorGen_$i.fa
done

#for x in {0...$SEED_RANGE}
echo ${#seed_arr[@]}

size=$((LOWEST_SIZE))
INCREMENT=0
#echo $size
for((x=1;x<=${#seed_arr[@]}; x++ ))
do
    j=$(($x-1))
    size=$(($size+$INCREMENT))
    INCREMENT=$(($INCREMENT_FACTOR*$LOWEST_SIZE))
    for y in {0..1}
    do
        #for z in {1..$SIZE_NUMBER}
        for((i=1;i<=$SEED_RANGE;i++ ))
        #for((z=$SEED_RANGE;z<=1; z-- ))
        do
            # echo $x
            s=$(($i-1))
            
            #size=$(($LOWEST_SIZE*$INCREMENT_FACTOR*$i))
            #size=$((1000*$i))
            #echo
            #seed=$(${seed_arr[x]})
            #if [ $i -gt $j ]
            #the
            
            # From equation:
            #$size= $lowest_size + ($i-1)* ($INCREMENT_FACTOR) * ($lowest_size)
            #we get:
            size_diff=$(($size-$LOWEST_SIZE))
            valid_i=$(echo $(($size_diff/$INCREMENT)))
            valid_i=$(($valid_i + 1))
            
            echo $valid_i
            echo $size " : " $s
            #echo "$size"
            if [ $size -eq $LOWEST_SIZE ]
            then
                ./AlcoR simulation -fs 1:$size:0:${seed_arr[$s]}:0.0$y:0:0:alcorGen_$i.fa >> $OUT_FILE
            else
                if [ $i -gt $valid_i ]
                then
                    ./AlcoR simulation -fs 1:$size:0:${seed_arr[$s]}:0.0$y:0:0:alcorGen_$i.fa >> $OUT_FILE
                fi
            fi
            #fi
        done
    done
done
####
sed -i '/^$/d' $OUT_FILE

faFiles=( $(ls | egrep "alcorGen_") );

for faFile in ${faFiles[@]}; do
  seqFile=$(echo $faFile | sed 's/.fa/.seq/g');
  cat "$faFile" | grep -v ">" | tr 'agct' 'AGCT' | tr -d -c "ACGT" > "$seqFile" # removes lines with comments and non-nucleotide chars
done
