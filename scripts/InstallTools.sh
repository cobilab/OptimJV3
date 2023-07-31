#!/bin/bash
#
function INSTALL_WITH_CONDA() {
    #
    # AlcoR ------------------------------------------------------------------------
    #
    conda install -y -c bioconda alcor
    #
    # GTO ------------------------------------------------------------------------
    #
    conda install -y -c cobilab gto
    #
    # JARVIS1 ----------------------------------------------------------------------
    #
    conda install -y -c bioconda jarvis
    #
    # GeCo3 ------------------------------------------------------------------------
    #
    conda install -y -c bioconda geco3
    #
    # GeCo2 ------------------------------------------------------------------------
    #
    conda install -y -c bioconda geco2
    #
    # NAF ------------------------------------------------------------------------
    #
    conda install -y -c bioconda naf
    #
    # AGC ------------------------------------------------------------------------
    #
    conda install -y -c bioconda agc
    #
    # MBGC ------------------------------------------------------------------------
    #
    conda install -y -c bioconda mbgc 
}
#
function INSTALL_WITHOUT_CONDA() {
    #
    # AlcoR ------------------------------------------------------------------------
    #
    # sudo apt-get install cmake git
    git clone https://github.com/cobilab/alcor.git
    cd alcor/src/
    cmake .
    make
    cp AlcoR ../..
    cd ../..
    rm -fr alcor
    #
    # GTO ------------------------------------------------------------------------
    #
    git clone https://github.com/bioinformatics-ua/gto.git
    mv gto gto_dir
    cd gto_dir/src/
    make
    cp ../bin/gto_fasta_to_seq ../bin/gto_fasta_from_seq ../bin/gto_fasta_split_reads ../../
    cd ../../
    rm -fr gto_dir
    #
    # JARVIS1 ----------------------------------------------------------------------
    #
    git clone https://github.com/pratas/jarvis.git
    cd jarvis/src/
    make
    cp JARVIS ../../
    cd ../../
    rm -fr jarvis
    #
    # GeCo3 ------------------------------------------------------------------------
    #
    git clone https://github.com/cobilab/geco3.git
    cd geco3/src/
    make
    cp GeCo3 ../../
    cp GeDe3 ../../
    cd ../../
    rm -fr geco3
    #
    # GeCo2 ------------------------------------------------------------------------
    #
    git clone https://github.com/pratas/geco2.git
    cd geco2/src/
    cmake .
    make
    cp GeCo2 ../../
    cp GeDe2 ../../
    cd ../../
    rm -fr geco2
    #
    # NAF ------------------------------------------------------------------------
    #
    # sudo apt install git gcc make diffutils perl # asks manual password
    git clone --recurse-submodules https://github.com/KirillKryukov/naf.git
    cd naf && make && make test && sudo make install
    cp ennaf/ennaf ../
    cp unnaf/unnaf ../
    cd ../
    rm -fr naf
    #
    # AGC ------------------------------------------------------------------------
    #
    git clone https://github.com/refresh-bio/agc
    cd agc && make
    cd ..
    mv agc agc_dir
    cp agc_dir/agc .
    rm -fr agc_dir
    #
    # MBGC ------------------------------------------------------------------------
    #
    git clone https://github.com/kowallus/mbgc.git
    cd mbgc
    mkdir -p build
    cd build
    cmake ..
    make mbgc
    cd ../../
    mv mbgc mbgc_dir # rename mbgc directory to move mbgc executable to scripts
    cp mbgc_dir/build/mbgc .
    rm -fr mbgc_dir
}


#
# === MAIN ===========================================================================
#

scriptPath=$(pwd)

binPath="../bin"
mkdir -p $binPath
cd $binPath

if [[ "$*" == *"--install-with-conda"* ||  "$*" == *"-iwc"* ]]; then
    INSTALL_WITH_CONDA;
elif [[ "$*" == *"--install-with-both"* ||  "$*" == *"-iwb"* ]]; then
    INSTALL_WITH_CONDA;
    INSTALL_WITHOUT_CONDA;
else
    INSTALL_WITHOUT_CONDA;
fi
# 
# The tools below cannot be installed with conda
#
# BSC --------------------------------------------------------------------------
#
rm -fr v0.2.1.tar.gz bsc-m03-0.2.1
wget https://github.com/IlyaGrebnov/bsc-m03/archive/refs/tags/v0.2.1.tar.gz
tar -vxzf v0.2.1.tar.gz
cd bsc-m03-0.2.1/
cmake .
make
cp bsc-m03 ..
cd ..
rm -fr bsc-m03-0.2.1/
#
# MFC --------------------------------------------------------------------------
#
rm -fr MFCompress-linux64-1.01.tgz MFCompress-linux64-1.01/
wget http://sweet.ua.pt/ap/software/mfcompress/MFCompress-linux64-1.01.tgz
tar -xvzf MFCompress-linux64-1.01.tgz
cp MFCompress-linux64-1.01/MFCompressC .
cp MFCompress-linux64-1.01/MFCompressD .
rm -fr MFCompress-linux64-1.01/ MFCompress-linux64-1.01.tgz
#
# JARVIS2 ----------------------------------------------------------------------
#
rm -rf JARVIS2-bin-64-Linux.zip extra JARVIS2.sh JARVIS2-bin-64-Linux/
wget https://github.com/cobioders/HumanGenome/raw/main/bin/JARVIS2-bin-64-Linux.zip
unzip -o JARVIS2-bin-64-Linux.zip
cp JARVIS2-bin-64-Linux/extra/* .
cp JARVIS2-bin-64-Linux/JARVIS2.sh .
cp JARVIS2-bin-64-Linux/JARVIS2 .
rm -fr JARVIS2-bin-64-Linux/ JARVIS2-bin-64-Linux.zip
#
# JARVIS3 ----------------------------------------------------------------------
#
git clone https://github.com/cobilab/jarvis3.git
cd jarvis3/src/
make
cp JARVIS3 JARVIS3.sh ../../
cd ../..
rm -fr jarvis3/
#
# NNCP -------------------------------------------------------------------------
#
rm -fr nncp-2021-06-01.tar.gz nncp-2021-06-01/
wget https://bellard.org/nncp/nncp-2021-06-01.tar.gz
tar -vxzf nncp-2021-06-01.tar.gz
cd nncp-2021-06-01/
make
cp nncp ../
cd ..
rm -fr nncp-2021-06-01/ nncp-2021-06-01.tar.gz
#
# CMIX ------------------------------------------------------------------------
#
git clone https://github.com/byronknoll/cmix.git
mv cmix cmix_dir
cd cmix_dir
# sudo apt update # asks manual password
# sudo apt install clang
make 
cd ..
cp cmix_dir/cmix .
cp cmix_dir/enwik9-preproc .
rm -fr cmix_dir
#
# MEMRGC ------------------------------------------------------------------------
#
git clone https://github.com/yuansliu/memrgc.git
mv memrgc memrgc_dir
cd memrgc_dir
make
cd ..
mv memrgc_dir/memrgc .
rm -fr memrgc_dir/
#
# DMcompress ------------------------------------------------------------------------
#
git clone https://github.com/rongjiewang/DMcompress.git
cp DMcompress/DMcompressC .
cp DMcompress/DMcompressD .
rm -fr DMcompress
#
# PAQ8l ------------------------------------------------------------------------
#
mkdir -p paq8l_dir
cd paq8l_dir
wget http://mattmahoney.net/dc/paq8l.zip
unzip paq8l.zip
g++ paq8l.cpp -O2 -DUNIX -DNOASM -s -o paq8l
rm -fr paq8l.zip
cd ..
mv paq8l_dir/paq8l .
rm -fr paq8l_dir

cd $scriptPath
