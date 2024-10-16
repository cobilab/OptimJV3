## <b>Optimize compression parameteres of Jarvis3</b> ##

<br>

<p align="justify">This repository provides optimization algorithms applied to Jarvis3 compressor.</p>

### Setup: ###

1. Clone this project:
<pre>
git clone https://github.com/cobilab/OptimJV3.git
</pre>

2. Setup:
<pre>
cd OptimJV3/scripts
chmod +x *.sh
./Setup.sh
</pre>

Alternatively, setup can be done as the following:
<pre>
./InstallTools.sh          # install JARVIS3, GTO, AlcoR, and other tools
./DownloadSequences.sh     # download Escherichia Coli, CY, and chm13v2.0 sequences
./PreprocessSequences.sh   # process FASTA and zipped sequences by removing headers, non-identifiable nucleobases, and uppercase base characters
./CreateSequences.sh       # optionally, create synthetic sequences
./GetSamples.sh            # extract human genome samples (recommended before constructing the DS table)
./GetDSinfo.sh             # sort processed sequences by size
</pre>

Then, if necessary, update path names and file names written in config.json.

### View Downloaded Sequences: ###

View information of stored sequences: 
<pre>
./Main.sh -v
</pre>

### Features: ###

The implemented features are listed in the following scripts:
<pre>
./Main.sh -h            # main script features
./GA.sh -h              # GA features
./Initialization.sh -h  # initialization features
./Run.sh -h             # ...
./Evaluation.sh -h      
./Selection.sh -h
./CrossMut.sh -h        # crossover and Mutation features
</pre>

### Basic examples: ###

To run a single GA, the following instruction may be executed (assuming cy is the sequence filename):
<pre>
# GA applied to optimization of human chromosome Y compression
# -s: sequence filename (without extension)
# -ga: name of folder where GA results are stored
# -lg: last generation number
# -t: number of threads to paralelize execution of JARVIS3 solutions
./GA.sh -s cy -ga "example" -lg 100 -t 10 # canonical GA example
</pre>

Alternatively, a set of pre-configured GAs can be executed as (assuming cy is the sequence filename):
<pre>
# GA applied to optimization of human chromosome Y compression
# -s: sequence filename (without extension)
# -lg: last generation number
# -t: number of threads to paralelize execution of JARVIS3 solutions
./Main.sh -s cy -lg 100 -t 10 # canonical GA example
</pre>

### Reproducibility: ###

It should be noted that, since the algorithm validates solutions based on memory used, in comparison to available memory (to avoid overuse of memory resources), there is no guarantee that all results will be identical.

To reproduce the metameric CGA's results for Escherichia coli (500 generations), CY (500 generations), and Cassava (20 generations), run the following:
<pre>
bash -x ./GA.sh -s "escherichia_coli" -ga "e0_ga1_lr0_cmga" -lr 0 -lg 500 1> out 2> err &
bash -x ./GA.sh -s cy -ga "e0_ga1_lr0_cmga" -lr 0 -lg 500 1> out 2> err &
bash -x ./GA.sh -s cassava -ga "e0_ga1_lr0_cmga" -lr 0 -lg 20 1> out 2> err &
</pre>

To reproduce the results for CY, execute the following:
<pre>
bash -x ./Main.sh -ds 15 -lg 100 -t 10 1> out 2> err &
</pre>

To reproduce the sampling results, execute the instructions written in the following script:
<pre>
./SamplingDemo.sh
</pre>
