#!/bin/bash

# get cassava sequence samples
./GetSamples.sh -s cassava
#
# === GA optimization for 100 generations
#
# run GAs
# (raising number of selected cmds, and crossover rate of commands and models in the first 100 generations)
sampleSizes=( "12d5MB" "25MB" "50MB" "100MB" )
for sampleSize in "${sampleSizes[@]}"; do
    bash -x ./GA.sh -s cassava$sampleSize -ga sampling100gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -ns 40 -cr 0.7 -mcr 0.7 -fg 1 -lg 100 1> out$sampleSize 2> err$sampleSize &
    wait
done
# #
# # sampling (part 1) from 100 generations optimization
# ./Sampling.sh -ga "sampling" -s "cassava"

# # sampling (part 2) from 100 generations optimization and for 100MB sample
# # -iga: input folder name
# # -oga: output folder name
# ./Sampling2.sh -s "cassava100MB" -iga "sampling" -oga "sampling2"

# # sampling (part 2) from 100 generations optimization and for complete genomic sequence
# ./Sampling2.sh -s "chm13v2.0" -iga "sampling" -oga "sampling2"

# #
# # === GA optimization for 200 generations (selection and crossover rates increased from generations 100 to 200)
# #
# # copy GA folders to run the algorithm on them
# samples=("cassava12d5MB" "cassava25MB" "cassava50MB" "cassava100MB")
# for s in ${samples[@]}; do
#     dsx="$(awk '/'$sequence'[[:space:]]/ { print $1 }' "$ds_sizesBase2")"
#     gaFolder="../$dsx/sampling"
#     gaFolder200="../$dsx/sampling200gens"
#     [ -d $gaFolder200 ] && mv $gaFolder200 ${gaFolder200}_bkp
#     cp -r $dsFolder $gaFolder200
# done

# # run GAs
# # (lowering number of selected cmds, and crossover rate of commands and models between generation 101 and 200)
# bash -x ./GA.sh -s cassava12d5MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 200 1> out 2> err & 
# bash -x ./GA.sh -s cassava25MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 200 1> out 2> err & 
# bash -x ./GA.sh -s cassava50MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 200 1> out 2> err & 
# bash -x ./GA.sh -s cassava100MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 200 1> out 2> err &

# # sampling (part 1) from 200 generations optimization 
# ./Sampling.sh -ga "sampling200gens"

# # sampling (part 2) from 100 generations optimization and for complete genomic sequence
# ./Sampling2.sh -s "cassava100MB" -iga "sampling200gens" -oga "sampling2_200gens"
