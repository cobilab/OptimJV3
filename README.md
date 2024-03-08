
## <b>Optimize compression parameteres of Jarvis3</b> ##

<br>

<p align="justify">This repository provides optimization algorithms applied to Jarvis3 compressor.</p>

### Reproducibility: ###

Change directory and give permitions:
<pre>
cd scripts/
chmod +x *.sh
./Main.sh
</pre>

Alternatively:
<pre>
cd scripts/
chmod +x *.sh
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
</pre>
