#!/bin/bash
#
# DS22 - cassava
./MainGA.sh -ds 22 -ga "ga1_cga" -fg 1 -lg 20 1> ds22ga1.log 2> ds22ga1.err &
./MainGA.sh -ds 22 -ga "ga2_cga_p20_ns6" -fg 1 -lg 20 -p20 -ns 6 1> ds22ga2.log 2> ds22ga2.err &
