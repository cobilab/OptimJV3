
## <b>How compressible are genome sequences?</b> ##

<br>

<p align="justify">This repository provides information-reproducibility on how compressible different genome sequences are using different data compressors.</p>

### Data compression tools ###

<br>
<div align="center">

| Data Compressor | Repository | Description  |
|-----------------|------------|--------------|
| AGC      |<a href="https://github.com/refresh-bio/agc">code</a>  | <a href="https://doi.org/10.1101/2022.04.07.487441">article</a>|
| bsc-m03 v0.2.1  |<a href="https://github.com/IlyaGrebnov/bsc-m03">code</a>  | <a href="https://github.com/IlyaGrebnov/bsc-m03">article</a>|
| bzip2 1.0.8     |<a href="https://sourceware.org/bzip2/">code</a>  | <a href="https://sourceware.org/bzip2/">article</a>|
| CMIX      |<a href="https://github.com/byronknoll/cmix">code</a>  | <a href="http://www.byronknoll.com/cmix.html ">article</a>|
| DMCompress      |<a href="https://rongjiewang.github.io/DMcompress/">code</a>  | <a href="https://doi.org/10.1109/BIBM.2016.7822621">article</a>|
| GeCo2           |<a href="https://github.com/cobilab/geco2">code</a>  | <a href="https://link.springer.com/chapter/10.1007/978-3-030-23873-5_17">article</a>|
| GeCo3           |<a href="https://github.com/cobilab/geco3">code</a>  | <a href="https://doi.org/10.1093/gigascience/giaa119">article</a>|
| JARVIS          |<a href="https://github.com/cobilab/jarvis">code</a>  | <a href="https://doi.org/10.3390/e21111074">article</a>|
| JARVIS2         |<a href="https://github.com/cobioders/jarvis2">code</a>  | <a href="https://ieeexplore.ieee.org/document/10125337/">article</a> |
| JARVIS3         |private  | under review |
| lzma 5.2.5      |<a href="https://tukaani.org/xz/">code</a>  | <a href="https://tukaani.org/xz/">article</a>|
| MBGC      |<a href="https://github.com/kowallus/mbgc">code</a>  | <a href="https://doi.org/10.1093/gigascience/giab099">article</a>|
| MemRGC      |<a href="https://github.com/yuansliu/memRGC">code</a>  | <a href="https://doi.org/10.1093/bioinformatics/btaa572">article</a>|
| MFCompress      |<a href="http://sweet.ua.pt/ap/software/mfcompress/MFCompress-linux64-1.01.tgz">code</a>  | <a href="https://doi.org/10.1093/bioinformatics/btt594">article</a>|
| NAF             |<a href="https://github.com/KirillKryukov/naf">code</a>  | <a href="https://doi.org/10.1093/bioinformatics/btz144">article</a>|
| paq8l           |<a href="http://mattmahoney.net/dc/paq8l.zip">code</a>  | <a href="http://mattmahoney.net/dc/#paq">article</a>|

</div>
<br>

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
./CleanCandDfiles.sh # optional
./Install_Tools.sh
./GetSeqs.sh
./CategorizeSeqBySize.sh
./GetOptimTestsExample.sh
./Plot.sh
</pre>
