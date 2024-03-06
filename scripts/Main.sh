#!/bin/bash
#
./CleanCandDfiles.sh # optional but recommended
./InstallTools.sh
./DownloadSequences.sh
./PreprocessSequences.sh
# ./CreateSequences.sh # optional
./CategorizeSeqBySize.sh
./RunTestsExample.sh
# ./SaveBenchAsTex.sh # optional 
./ProcessBenchRes.sh
./Plot.sh
