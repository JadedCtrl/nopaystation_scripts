#!/bin/bash

# AUTHOR sigmaboy <j.sigmaboy@gmail.com>

if [ "${1}" == "-a" ]
then
    ALL=1
    shift
else
    ALL=0
fi

# get directory where the scripts are located
SCRIPT_DIR="$(dirname "$(readlink -f "$(which "${0}")")")"

# source shared functions
. "${SCRIPT_DIR}/functions.sh"

### usage function
my_usage(){
    echo ""
    echo "Parameters:"
    echo "${0} \"TITLE_ID\" \"http://announce.url\" \"/path/to/nps/directory\" \"SOURCE_TAG\""
    echo ""
    echo "The SOURCE_TAG parameter is optional. All other parameters are required."
    echo "So if you don't want to set the source tag, just leave it off."
    echo "This is required for private torrent trackers only"
    echo ""
    echo "Usage:"
    echo "${0} \"PCSE00986\" \"http://announce.url\" \"/home/Downloads/nps\" \"GGn\""
}

my_mktorrent(){
    local TORRENT_SOURCE="${1}"
    if [ "${SOURCE_ENABLE}" -eq 0 ]
    then
        mktorrent -dpa "${ANNOUNCE_URL}" "${TORRENT_SOURCE}"
    else
        mktorrent -dpa "${ANNOUNCE_URL}" -s "${SOURCE_TAG}" "${TORRENT_SOURCE}"
    fi
}

# check if necessary binaries are available
MY_BINARIES="pkg2zip mktorrent sed"
check_binaries "${MY_BINARIES}"

TITLE_ID="${1}"
ANNOUNCE_URL="${2}"
NPS_DIR="${3}"
if [ -z "${4}" ]
then
    SOURCE_ENABLE=0
else
    SOURCE_TAG="${4}"
    SOURCE_ENABLE=1
fi

if ! echo "${TITLE_ID}" | grep -E -i 'PCS[ABCDEFGH][0-9]{5}' > /dev/null
then
    echo ""
    echo "Error"
    echo "Media ID is not valid."
    echo "It should be the following format:"
    echo "PCSA01234"
    echo "Check your first parameter."
    exit 1
fi

### check if every parameter is set
if [ -z "${TITLE_ID}" ] || [ -z "${ANNOUNCE_URL}" ] || [ -z "${NPS_DIR}" ]
then
    echo "ERROR: Not every necessary option specified."
    my_usage
    exit 1
fi

### check if nps tsv file directory exists
if [ ! -d "${NPS_DIR}" ]
then
    echo "Directory containing *.tsv files missing (\"${NPS_DIR}\"). Check your path parameter."
    my_usage
    exit 1
fi

### check if the tsv files are available to call download scripts
tsv_files="PSV_GAMES.tsv PSV_DLCS.tsv PSV_UPDATES.tsv"
for tsv_file in $tsv_files
do
    if [ ! -f "${NPS_DIR}/${tsv_file}" ]
    then
        echo "*.tsv file \"${tsv_file}\" in path \"${NPS_DIR}\" missing."
        exit 1
    fi
done

check_announce_url "${ANNOUNCE_URL}"

### Download the chosen game
download_game.sh "${NPS_DIR}/PSV_GAMES.tsv" "${TITLE_ID}"
if [ $? -ne 0 ]
then
    echo ""
    echo "Game cannot be downloaded. Skipping further steps."
    exit 1
fi

### Get name of the zip file from generated txt created via download_game.sh
GAME_NAME="$(cat "${TITLE_ID}.txt")"
ZIP_FILENAME="${GAME_NAME}.zip"

### Download available updates. With parameter -a all updates
if [ "${ALL}" -eq 1 ]
then
    DESTDIR="${GAME_NAME}" download_update.sh -a "${TITLE_ID}"
else
    DESTDIR="${GAME_NAME}" download_update.sh "${TITLE_ID}"
fi

### Download available DLC
DESTDIR="${GAME_NAME}" download_dlc.sh "${NPS_DIR}/PSV_DLCS.tsv" "${TITLE_ID}"

### Creating the torrent files
rm -f "${ZIP_FILENAME}.torrent"
echo "Creating torrent file for \"${GAME_NAME}.zip\""
my_mktorrent "${ZIP_FILENAME}"
if [ -d "${GAME_NAME}_update" ]
then
    test -e "${GAME_NAME}_update.torrent" && rm -f "${GAME_NAME}_update.torrent"
    echo "Creating torrent file for directory \"${GAME_NAME}_update\""
    my_mktorrent "${GAME_NAME}_update"
fi
if [ -d "${GAME_NAME}_dlc" ]
then
    test -e "${GAME_NAME}_dlc.torrent" && rm -f "${GAME_NAME}_dlc.torrent"
    echo "Creating torrent file for directory \"${GAME_NAME}_dlc\""
    my_mktorrent "${GAME_NAME}_dlc"
fi

### remove temporary game name file
rm "${TITLE_ID}.txt"

### Run post scripts
if [ -x ./download2torrent_post.sh ]
then
    ./download2torrent_post.sh "${GAME_NAME}"
fi
