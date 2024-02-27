#!/bin/bash
#
./CleanCandDfiles.sh # optional but recommended
./Install_Tools.sh
./GetSequences.sh 
# ./CreateSequences.sh # optional
./CategorizeSeqBySize.sh
./RunTestsExample.sh
# ./SaveBenchAsTex.sh # optional 
./ProcessBenchRes.sh
./Plot.sh
