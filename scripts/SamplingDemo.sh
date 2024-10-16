#
# === GA optimization for 100 generations
#
# run GAs 
bash -x ./GA.sh -s human12d5MB -ga sampling_150generations -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 150 1> out 2> err & 
bash -x ./GA.sh -s human25MB -ga sampling_150generations -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 150 1> out 2> err &
bash -x ./GA.sh -s human50MB -ga sampling_150generations -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 150 1> out 2> err &
bash -x ./GA.sh -s human100MB -ga sampling_150generations -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -fg 101 -lg 150 1> out 2> err &

# sampling (part 1) from 100 generations optimization
./Sampling.sh -ga "sampling"

# sampling (part 2) from 100 generations optimization and for 100MB sample
# -iga: input folder name
# -oga: output folder name
./Sampling2.sh -s "human100MB" -iga "sampling" -oga "sampling2"

# sampling (part 2) from 100 generations optimization and for complete human genome
./Sampling2.sh -s "chm13v2.0" -iga "sampling" -oga "sampling2"

#
# === GA optimization for 200 generations (selection and crossover rates increased from generations 100 to 200)
#
# run GAs
bash -x ./GA.sh -s human12d5MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -ns 40 -cr 0.7 -mcr 0.7 -fg 101 -lg 200 1> out 2> err & 
bash -x ./GA.sh -s human25MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -ns 40 -cr 0.7 -mcr 0.7 -fg 101 -lg 200 1> out 2> err & 
bash -x ./GA.sh -s human50MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -ns 40 -cr 0.7 -mcr 0.7 -fg 101 -lg 200 1> out 2> err & 
bash -x ./GA.sh -s human100MB -ga sampling200gens -hyi -hhp 0.5 -sl "rws" -cc "rmga" -c "u" --moga -wBPS 0.5 -ns 40 -cr 0.7 -mcr 0.7 -fg 101 -lg 200 1> out 2> err &

# sampling (part 1) from 200 generations optimization 
./Sampling.sh -ga "sampling200gens"

# sampling (part 2) from 100 generations optimization and for complete human genome
./Sampling2.sh -s "human100MB" -iga "sampling200gens" -oga "sampling2_200gens"
