# clean compressed and decompressed files
sequencesPath="$HOME/sequences"
find $sequencesPath -maxdepth 1 ! -name "*.fa" ! -name "*.seq" -type f -delete
