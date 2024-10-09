## <b>Optimize compression parameteres of Jarvis3</b> ##

<br>

<p align="justify">This repository provides optimization algorithms applied to Jarvis3 compressor.</p>

### Reproducibility: ###

1. Setup:
<pre>
./Setup.sh
</pre>

Alternatively, setup can be done as the following:
<pre>
./InstallTools.sh          # install JARVIS3, GTO, AlcoR, and other tools
./DownloadSequences.sh     # download sequences
./PreprocessSequences.sh   # process FASTA and zipped sequences by removing headers, non-identifiable nucleobases, and uppercase base characters
# ./CreateSequences.sh     # optionally, create synthetic sequences
./GetDSinfo.sh             # sort processed sequences by size
</pre>

2. After cloning this repository, a single GA can be executed as:
<pre>
# GA applied to optimization of human chromosome Y compression
# -s: sequence filename (without extension)
# -ga: name of folder where GA results are stored
# -lg: last generation number
# -t: number of threads to paralelize execution of JARVIS3 solutions
./GA.sh -s cy -ga "example" -lg 500 -t 10 # canonical GA example
</pre>

Alternatively, a sample collection of GAs can be executed as:
<pre>
# GA applied to optimization of human chromosome Y compression
# -s: sequence filename (without extension)
# -lg: last generation number
# -t: number of threads to paralelize execution of JARVIS3 solutions
./Main.sh -s cy -lg 500 -t 10 # canonical GA example
</pre>

Help:
<pre>
./Main.sh -h
</pre>

View information of stored sequences: 
<pre>
./Main.sh -v
</pre>
