#!/bin/bash
#
configJson="../config.json"
rawSequencesPath="$(grep 'rawSequencesPath' $configJson | awk -F':' '{print $2}' | tr -d '[:space:],"' )";
mkdir -p $rawSequencesPath;
rawCassavaPath="../cassava_raw"
#
cassavaFiles=( $rawCassavaPath/*.gz )
for cassavaFile in "${cassavaFiles[@]}";do
    gunzip -c "$cassavaFile" > "$rawSequencesPath/${cassavaFile/.gz/}"
    mv "$rawSequencesPath/${cassavaFile/.gz/}" $rawSequencesPath
done
