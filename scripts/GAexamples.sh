#!/bin/bash
#
# DS13 - CY
#
# DS22 - cassava
./MainGA.sh -ds 22 -ga "ga1_cga" -fg 1 -lg 20 1> ds22ga1.log 2> ds22ga1.err & # -ps 100 -ns 30
./MainGA.sh -ds 22 -ga "ga2_cga_p10_ns4_cr1" -fg 1 -lg 20 -ps 10 -ns 4 -cr 1 1> ds22ga2.log 2> ds22ga2.err & # cr=1, otherwise population is very likely to stagnate
./MainGA.sh -ds 22 -ga "ga3_cga_p20_ns6" -fg 1 -lg 20 -p 20 -ns 6 -t 6 1> ds22ga3.log 2> ds22ga3.err &
./MainGA.sh -ds 22 -ga "ga4_cga_p50_ns16" -fg 1 -lg 20 -p 50 -ns 16 1> ds22ga4.log 2> ds22ga4.err &
./MainGA.sh -ds 22 -ga "ga5_cga_p80_ns24" -fg 1 -lg 20 -p 80 -ns 24 1> ds22ga5.log 2> ds22ga5.err &
