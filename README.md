
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
./MainGA.sh -ds 1 -ga "ga1_cga"
</pre>

Help: 
<pre>
./MainGA.sh -h
</pre>

View downloaded sequences: 
<pre>
./MainGA.sh -v
</pre>

`MainGA.sh` has been executed with the following commands: 

### DS13 - CY ###

```bash
./MainGA.sh -ds 13 -ga "ga1_cga" -fg 1 -lg 20 # -ps 100 -ns 30
#
# GAs that vary in population size
./MainGA.sh -ds 13 -ga "ga2_cga_p10_ns4" -fg 1 -lg 20 -ps 10 -ns 4
./MainGA.sh -ds 13 -ga "ga3_cga_p20_ns6" -fg 1 -lg 20 -ps 20 -ns 6
./MainGA.sh -ds 13 -ga "ga4_cga_p50_ns16" -fg 1 -lg 20 -ps 50 -ns 16
./MainGA.sh -ds 13 -ga "ga5_cga_p80_ns24" -fg 1 -lg 20 -ps 80 -ns 24
#
# GAs that vary in population size (crossover rate=1)
./MainGA.sh -ds 13 -ga "ga6_cga_p10_ns4_cr1" -fg 1 -lg 20 -ps 10 -ns 4 -cr 1
./MainGA.sh -ds 13 -ga "ga7_cga_p20_ns6_cr1" -fg 1 -lg 20 -ps 20 -ns 6 -cr 1
./MainGA.sh -ds 13 -ga "ga8_cga_p50_ns16_cr1" -fg 1 -lg 20 -ps 50 -ns 16 -cr 1
./MainGA.sh -ds 13 -ga "ga9_cga_p80_ns24_cr1" -fg 1 -lg 20 -ps 80 -ns 24 -cr 1
```

### DS22 - Cassava ###

```bash
./MainGA.sh -ds 22 -ga "ga1_cga" -fg 1 -lg 20 # -ps 100 -ns 30
#
# GAs that vary in population size
./MainGA.sh -ds 22 -ga "ga2_cga_p10_ns4" -fg 1 -lg 20 -ps 10 -ns 4
./MainGA.sh -ds 22 -ga "ga3_cga_p20_ns6" -fg 1 -lg 20 -ps 20 -ns 6
./MainGA.sh -ds 22 -ga "ga4_cga_p50_ns16" -fg 1 -lg 20 -ps 50 -ns 16
./MainGA.sh -ds 22 -ga "ga5_cga_p80_ns24" -fg 1 -lg 20 -ps 80 -ns 24
#
# GAs that vary in population size (crossover rate=1)
./MainGA.sh -ds 22 -ga "ga6_cga_p10_ns4_cr1" -fg 1 -lg 20 -ps 10 -ns 4 -cr 1
./MainGA.sh -ds 22 -ga "ga7_cga_p20_ns6_cr1" -fg 1 -lg 20 -ps 20 -ns 6 -cr 1
./MainGA.sh -ds 22 -ga "ga8_cga_p50_ns16_cr1" -fg 1 -lg 20 -ps 50 -ns 16 -cr 1
./MainGA.sh -ds 22 -ga "ga9_cga_p80_ns24_cr1" -fg 1 -lg 20 -ps 80 -ns 24 -cr 1
```
