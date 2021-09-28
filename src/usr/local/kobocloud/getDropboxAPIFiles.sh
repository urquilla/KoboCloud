#!/bin/sh
#set -v
#set -x
#set -e

dropboxToken="$1"
outDir="$2"

echo "getDropboxAPIFiles args: $@"
#load config
. $(dirname $0)/config.sh

# get directory listing
echo "Getting $baseURL"
# get directory listing ( IMPORTANT: note that any special chars different than a quote will break this!)

REMOTE_FILES=$($CURL -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.89 Safari/537.36" -k -L --silent curl -X POST https://api.dropboxapi.com/2/files/list_folder \
  --header "Authorization: Bearer ${dropboxToken}" \
  --header 'Content-Type: application/json' \
  --data '{"path":"","recursive":true,"limit":2000,"include_media_info":true}' | # Get list of files and dirs in root dir (App scoped)
sed 's/{/\n{/g' | grep '".tag": "file"' | sed 's/{/{\n/g' | sed 's/",/",\n/g' | sed 's/}/\n}/g' | # Filter for files only
grep -E 'path_lower' | cut -d '"' -f 4- | rev | cut -d '"' -f2- | rev | # Get download paths
xargs -0 -I {} -n1 echo "{}") # Going all the hacky way with curly braces in place of \


LOCAL_FILES=$(find "${outDir}" -type f | sort -u)
EXPECTED_FILES=$(echo "${REMOTE_FILES}" | xargs -I {} -n1 echo "${outDir}{}" | sort -u)

echo "**** Data set LOCAL****"
echo "${LOCAL_FILES}"
echo "**** Data set REMOTE****"
echo "${EXPECTED_FILES}"

IFS='
'
DIFF=$(echo "${LOCAL_FILES}" | grep -v "${EXPECTED_FILES}")
echo "DIFF: ${DIFF}"


if [ -z "${DIFF}" ]; then
  echo "No changes in remote library, exiting..."
  exit 0
fi



IFS='
'

# Remove files no longer present
echo
echo "=== CHECKING LOCAL FILES ==="
for f in ${LOCAL_FILES}; do
  echo "Checking local file: $f"
  status=0
  echo "${EXPECTED_FILES}" | grep -x "^${f}$" || status=$?
  echo "MISSING? ${status} (0 = found)"
  # If file not found in expected files remove
  if [ $status -ne 0 ]; then
    echo "REMOVING: ${f}"
    rm ${f}
  fi
done

echo
echo "=== CHECKING REMOTE FILES ==="

# Download new files
for f in ${REMOTE_FILES}; do
  EXPECTED_LOCAL=$(echo "${outDir}${f}")
  echo "Checking remote file: ${EXPECTED_LOCAL}"
  status=0
  echo "${LOCAL_FILES}" | grep -E "^${EXPECTED_LOCAL}$" || status=$?
  echo "MISSING? ${status} (0 = found)"
  # If file not found locally, download
  if [ $status -ne 0 ]; then
    echo "DOWNLOADING: ${f}"
    $KC_HOME/getRemoteDropboxAPIFile.sh "${f}" "$dropboxToken" "${EXPECTED_LOCAL}"
  fi
done


#for d in $REMOTE_FILES; do
#IFS='
#'
  #echo "$outDir$d"
  #$KC_HOME/getRemoteDropboxAPIFile.sh "${d}" "$dropboxToken" "$outDir${d}"
#done
