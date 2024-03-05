#!/bin/bash

mkdir -p ../optimRes;
mkdir -p ../optimResGen;

# numBestRes=5;

../bin/JARVIS3_with_output -o ../../sequences/mt_genome_CM029732.1.seq.jc ../../sequences/mt_genome_CM029732.seq; ../bin/JARVIS3_with_output -d ../../sequences/mt_genome_CM029732.1.seq.jc
./GetOptimTests.sh --seq mt_genome_CM029732 -o 1 -n 1 1> ../optimRes/bench-results-raw-ds1.txt 2> ../optimRes/err/xs_ds1_err.txt & 

./GetOptimTests.sh --size xs 1> ../optimRes/bench-results-raw-xs.txt 2> ../optimRes/err/xs_err.txt &
./GetOptimTests.sh --size s 1> ../optimRes/bench-results-raw-s.txt 2> ../optimRes/err/s_err.txt &
./GetOptimTests.sh --size m 1> ../optimRes/bench-results-raw-m.txt 2> ../optimRes/err/m_err.txt &
./GetOptimTests.sh --size l 1> ../optimRes/bench-results-raw-l.txt 2> ../optimRes/err/l_err.txt &

# specific sequences from group s, with -o flag:
./GetOptimTests.sh --seq Spheniscus_demersus.cds.v1 -o 1 -n 25 1> ../optimRes/bench-results-raw-ds10.1.txt 2> ../optimRes/err/s_ds10_1_err.txt & 

# alternatively, to run optmization on a specific sequence from group m:
./GetOptimTests.sh --seq Helostoma_temminckii.genome 1> ../optimRes/bench-results-raw-ds15.txt 2> ../optimRes/err/m_ds15_err.txt & 

./GetOptimTests.sh --seq Chelmon_rostratus.genome 1> ../optimRes/bench-results-raw-ds16.txt 2> ../optimRes/err/m_ds16_err.txt & 
./GetOptimTests.sh --seq Chaetodon_tr.seqsciatus.genome 1> ../optimRes/bench-results-raw-ds17.txt 2> ../optimRes/err/m_ds17_err.txt & 
./GetOptimTests.sh --seq TME204.HiFi_HiC.haplotig2 1> ../optimRes/bench-results-raw-ds18.txt 2> ../optimRes/err/m_ds18_err.txt & 
./GetOptimTests.sh --seq TME204.HiFi_HiC.haplotig1 1> ../optimRes/bench-results-raw-ds19.txt 2> ../optimRes/err/m_ds19_err.txt & 
./GetOptimTests.sh --seq Naso_vlamingii.genome 1> ../optimRes/bench-results-raw-ds20.txt 2> ../optimRes/err/m_ds20_err.txt & 

./GetOptimTests.sh --seq Rhodeus_ocellatus.genome -o 1 -n 25 1> ../optimRes/bench-results-raw-ds21.1.txt 2> ../optimRes/err/m_ds21_1_err.txt & 
./GetOptimTests.sh --seq Rhodeus_ocellatus.genome -o 2 -n 25 1> ../optimRes/bench-results-raw-ds21.2.txt 2> ../optimRes/err/m_ds21_2_err.txt & 

./GetOptimTests.sh --seq Pseudobrama_simoni.genome -o 1 -n 25 1> ../optimRes/bench-results-raw-ds22.1.txt 2> ../optimRes/err/m_ds22_1_err.txt & 
./GetOptimTests.sh --seq Pseudobrama_simoni.genome -o 2 -n 25 1> ../optimRes/bench-results-raw-ds22.2.txt 2> ../optimRes/err/m_ds22_2_err.txt & 
./GetOptimTests.sh --seq Pseudobrama_simoni.genome -o 3 -n 2 1> ../optimRes/bench-results-raw-ds22.2.txt 2> ../optimRes/err/m_ds22_2_err.txt & # faltam 20

# alternatively, to run optmization on a specific sequence from group s:
# ./GetOptimTests.sh --seq ensete_glaucum.evm.cds -n 50 > ../optimRes/bench-results-raw-ds14.txt 2>&1 & 
# ./GetOptimTests.sh --seq Spheniscus_magellanicus.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds13.txt 2>&1 & 
# ./GetOptimTests.sh --seq Eudyptes_moseleyi.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds12.txt 2>&1 & 
# ./GetOptimTests.sh --seq Megadyptes_antipodes_antipodes.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds11.txt 2>&1 & 
# ./GetOptimTests.sh --seq Spheniscus_demersus.cds.v1 -n 50 > ../optimRes/bench-results-raw-ds10.txt 2>&1 & 

# ./GetOptimTests.sh --seq ensete_glaucum.evm.cds -n 50 1> ../optimRes/bench-results-raw-ds14.txt 2> ../logs/bench-results-raw-ds14.txt & 
# ./GetOptimTests.sh --seq Spheniscus_demersus.cds.v1 -n 50 1> ../optimRes/bench-results-raw-ds10.txt &  2> ../logs/bench-results-raw-ds10.txt &

# ./GetOptimTests.sh --seq chm13v2.0 -n 10 > ../optimRes/bench-results-raw-ds25.txt 2>&1 &

# already sorts results from best (lowest bps and c_time) to worst and saves top N results and top N commands
./ProcessBenchRes.sh

# ./ProcessBenchRes.sh --dir optimResGen

# ./Plot.sh
# ./Plot.sh --dir optimResGen
