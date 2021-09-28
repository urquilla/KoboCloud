#!/bin/sh

pathline="$1"
auth="$2"
localFile="$3"
user="$4"
outputFileTmp="/tmp/kobo-remote-file-tmp.log"

echo "DOWNLOADING: $pathline to $localFile"

# add the epub extension to kepub files
if echo "$localFile" | grep -Eq '\.kepub$'
then
    localFile="$localFile.epub"
fi

#load config
. $(dirname $0)/config.sh

curlCommand="$CURL"
if [ ! -z "$user" ] && [ "$user" != "-" ]; then
    echo "User: $user"
    curlCommand="$curlCommand -u $user: "
fi

echo "Download: $curlCommand -k -X POST 'https://content.dropboxapi.com/2/files/download' --silent -C - -L --create-dirs -o \"$localFile\" --header \"Authorization: Bearer ${auth}\" \
  --header \"Dropbox-API-Arg: {\"path\":\"${pathline}\"}\" -v"

$curlCommand -k -X POST 'https://content.dropboxapi.com/2/files/download' --silent -C - -L --create-dirs -o "$localFile" --header "Authorization: Bearer ${auth}" \
  --header "Dropbox-API-Arg: {\"path\":\"${pathline}\"}" -v 2>$outputFileTmp
status=$?
echo "Status: $status"
#echo "Output: "
#cat $outputFileTmp

statusCode=`cat $outputFileTmp | grep 'HTTP/' | tail -n 1 | cut -d' ' -f3`
rm $outputFileTmp

echo "Remote file information:"
echo "  Status code: $statusCode"

if echo "$statusCode" | grep -q "403"; then
    echo "Error: Forbidden"
    exit 2
fi
if echo "$statusCode" | grep -q "50.*"; then
    echo "Error: Server error"
    exit 3
fi

echo "getRemoteFile ended"