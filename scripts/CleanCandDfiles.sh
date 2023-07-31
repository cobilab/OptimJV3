# clean compressed and decompressed files
find . -maxdepth 1 ! -name "*.sh" ! -name "*.fa" ! -name "*.seq" ! -name "*.csv" -type f -delete && rm -fr *_out*
