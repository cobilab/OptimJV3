
## <b>Optimize compression parameteres of Jarvis3</b> ##

<br>

<p align="justify">This repository provides optimization algorithms applied to Jarvis3 compressor.</p>

### Reproducibility: ###

Install jarvis3:
<pre>
git clone https://github.com/cobilab/jarvis3.git
cd jarvis3/src/
make
</pre>

After cloning this repository:
<pre>
mv /path/to/jarvis3/src/JARVIS3 scripts/
cd scripts/
chmod +x *.sh
./Setup.sh
./GA.sh -ds 1 -ga "ga1_cga" # canonical GA example
</pre>

Help: 
<pre>
./Main.sh -h
</pre>

View downloaded sequences: 
<pre>
./Main.sh -v
</pre>
