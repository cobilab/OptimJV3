#!/bin/bash
#
function SPLICE() {
    for model in "${models[@]}"; do 
        for cmd in "${couple[@]}"; do
            splicedData+=$(echo "$cmd" | grep -oE "\-$model [0-9:./]+" | tr '\n' ' ')
        done
    done
    printf "SPLICED DATA\n\t$splicedData\n\n"
}
#
function SHUFFLE() { # $(echo "$command" | grep -oE '\-cm [0-9:./]+' | sed 's/-cm//g' | tr '\n' ' ')
    for model in "${models[@]}"; do 
        seed=$((seed+si)) && shuffledData+=$(echo "$splicedData" | grep -oE "\-$model [0-9:./]+" | sort -R --random-source=<(yes $seed) | tr '\n' ' ')
    done
    printf "SHUFFLED DATA\n\t$shuffledData\n\n"
}
#
function CROSSOVER() {
    echo crossover
}
#
function CUT() {
    for model in "${models[@]}"; do
        numModels=$(echo "$shuffledData" | grep -oE "\-$model [0-9:./]+" | wc -l)
        # echo $numModels
        modelDataArr=( $(echo "$shuffledData" | grep -oE "\-$model [0-9:./]+" | sed "s/-$model//g" | tr '\n' ' ') )
        #
        avgModels=$((numModels/numChildren))
        [ $avgModels -eq 0 ] && avgModels=1
        echo $model $avgModels
        #
        for i in $(seq 1 $numChildren); do
            [ $((i%2)) -ne 0 ] && rnd=$((RANDOM%avgModels)) && cut=$((avgModels+rnd))|| cut=$((avgModels-rnd))
            [ $i -eq $numChildren ] && cut="${#modelDataArr[@]}"
            for c in $(seq $cut); do
                children[i-1]+=" -$model ${modelDataArr[0]}"
                modelDataArr=( ${modelDataArr[@]:1} )
            done
        done
        #
        unset modelDataArr
    done
    #
    printf "child %s \n" "${children[@]}"
}   
#
# ============================================================================
#
seed=10 && si=10
RANDOM=$seed
#
minCMs=1
maxCMs=5
minRMs=0
maxRMs=3
#
couple=(
    "../jv3/JARVIS3 -v -lr 0.01 -hs 50 -cm 3:396:2:0.61/7:4273:0:0.90 -cm 12:4416:2:0.65/1:1529:1:0.65 -cm 6:2431:1:0.43/6:302:1:0.42 -cm 12:4416:2:0.65/1:1529:1:0.97 -rm 413:12:0.16:4:0.72:2:0.74:1 ../../sequences/CY.seq"
    "../jv3/JARVIS3 -v -lr 0.01 -hs 70 -cm 12:850:2:0.47/17:2139:0:0.09 -cm 4:4061:1:0.40/6:1312:0:0.35 -cm 4:3409:0:0.35/10:1292:0:0.14 -rm 292:3:0.08:9:0.69:0:0.66:4 ../../sequences/CY.seq"
    "../jv3/JARVIS3 -v -lr 0.05 -hs 45 -cm 10:4477:0:0.32/6:580:0:0.84 ../../sequences/CY.seq"
    "../jv3/JARVIS3 -v -lr 0.02 -hs 42 -cm 2:794:0:0.05/3:196:1:0.32 -cm 6:4098:0:0.87/17:871:0:0.92 -cm 12:4134:1:0.94/16:4862:0:0.27 -rm 362:11:0.21:11:0.99:1:0.34:2 ../../sequences/CY.seq"
)
#
numChildren="${#couple[@]}"
#
crossRate=0.6
rndNum=0.7
if (( $(echo "$rndNum>$crossRate"|bc) )); then 
    models=($(echo "${couple[0]}" | grep -oE '\-[a-zA-Z]+' | grep -v "\-v" | sed 's/-//g' | uniq))
    SPLICE
    SHUFFLE
    CROSSOVER
    CUT
fi
