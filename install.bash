#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "needs to be run as root"
  return 1
fi

mkdir /opt/auto-root
cp ./auto-root.bash /opt/auto-root/auto-root.bash

#replaceInFile contentFile targetFile startMarker endMarker
function replaceInFile(){
    if [[ $# != 4 ]]; then
        echo "Internal script error: wrong number of parameters"
        return 1
    fi

    contentFile=$1
    targetFile=$2
    startMarker=$3
    endMarker=$4

    if ! grep -q "$startMarker" "$targetFile"; then
        #String was not found in targetFile
        echo "Adding contents from $contentFile to $targetFile"
        cat "$contentFile" >> "$targetFile"
    else
        echo "Updating contents from $contentFile to $targetFile"
        ed "$targetFile"<<EOF
/^$startMarker
+,/^$endMarker/-1d
-r !sed -n '/^$startMarker/,/^$endMarker/p' $contentFile|grep -v '^##'
w
q
EOF
    fi
}

replaceInFile ./auto-root-shrc ~/.bashrc "## auto root ##" "## end auto root ##"

tempfilesPath="$(findmnt -cfn -o TARGET tmpfs)/auto-root"
bashrcTempfilesPathString="autoRootTempFileDir=\"$tempfilesPath\""

sed -i "/autoRootTempFileDir/c\    ${bashrcTempfilesPathString}" ~/.bashrc
