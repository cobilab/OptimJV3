#!/bin/bash
#
./CleanCandDfiles.sh # optional but recommended
./Install_Tools.sh
./GetGens.sh 
# ./CreateGens.sh # optional
./CategorizeSeqBySize.sh
./RunTestsExample.sh
# ./SaveBenchAsTex.sh # optional 
./ProcessRawBench.sh
./Plot.sh
