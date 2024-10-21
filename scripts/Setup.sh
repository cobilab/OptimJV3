#!/bin/bash
#
./InstallTools.sh      # install JARVIS3, GTO, and AlcoR
./DownloadFASTA.sh     # downloads FASTA files
./GetAlcoRFASTA.sh     # simulates and stores 2 synthetic FASTA sequences
./FASTA2seq.sh         # cleans FASTA files and stores raw sequence files
./DownloadDNAcorpus.sh # download raw sequences from a balanced sequence corpus
./GetDSinfo.sh         # map sequences into their ids, sorted by size; view sequences info
