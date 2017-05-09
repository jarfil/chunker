#!/bin/bash

#   Copyright 2017 Jaroslaw Filiochowski
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


function printhelp {
	echo "Usage: $0 [OPTION]... FILE TARGET_DIR CHUNK_SIZE"
	echo "Split FILE in CHUNK_SIZE byte chunks compressing chunks with gzip in parallel."
	echo
	echo "      --dry-run  just output the makefile"
	echo "      --start=n  start processing at chunk number n"
	echo "      --end=n    end processing at chunk number n"
	echo "      --help     display this help and exit"
	echo
	echo "CHUNK_SIZE must be an integer with an optional KB, MB or GB suffix (powers of 1000)"
}

#===
# process parameters

DRYRUN=0
CHUNKSTART=0
CHUNKEND="all"

while [[ $# -gt 0 ]] ; do
	case "$1" in
	"--dry-run")
		DRYRUN=1
		shift
		;;
	"--start="*)
		CHUNKSTART="${1#--start=}"
		shift
		;;
	"--end="*)
		CHUNKEND="${1#--end=}"
		shift
		;;
	"--help")
		printhelp
		exit 0
		;;
	*)
		if [[ $# -ne 3 ]] ; then
			printhelp
			exit 1
		fi

		FILENAME="$1"
		TARGETDIR="$2"
		CHUNKSIZE="$3"
		shift 3
	esac
done

if [ "$FILENAME" == "" ] ; then
	printhelp
	exit 1
fi

#===
# sanitize input

SANITIZEOK=1

if [[ ! "$CHUNKSTART" =~ ^[0-9]*$ ]] ; then
	echo "chunker: option --start requires an integer"
	SANITIZEOK=0
fi

if [ "$CHUNKEND" != "all" ] ; then
	if [[ ! "$CHUNKEND" =~ ^[0-9]*$ ]] ; then
		echo "chunker: option --end requires an integer"
		SANITIZEOK=0
	fi
fi

if [ ! -f "$FILENAME" ] ; then
	echo "chunker: can't find input file: $FILENAME"
	SANITIZEOK=0
fi

if [ ! -d "$TARGETDIR" ] ; then
	echo "chunker: can't find target directory: $TARGETDIR"
	SANITIZEOK=0
fi

if [ "${CHUNKSIZE:(-1)}" == "B" ] ; then
	CHUNKSIZE=${CHUNKSIZE%?}
	CHUNKSIZE=`echo "$CHUNKSIZE" | sed "s/[Gg]$/kkk/g;s/[Mm]$/kk/g;s/[Kk]/000/g;"`
fi

if [[ ! "$CHUNKSIZE" =~ ^[0-9]*$ ]] ; then
	echo "chunker: chunk size must be an integer with an optional KB, MB or GB suffix (powers of 1000)"
	SANITIZEOK=0
fi

if [ "$SANITIZEOK" != 1 ] ; then
	exit 1
fi

#===
# prepare

MAKEFILE=`mktemp`
FILESIZE=$(stat -c%s "$FILENAME")

let CHUNKS=FILESIZE/CHUNKSIZE

# not needed, dd will be zero based
#let T=CHUNKSIZE*CHUNKS
#if [ $T -lt $FILESIZE ] ; then
#	let CHUNKS++
#fi

#===
# main loop

# replaces:
# cat ../SYSTEM-bak01.VHD | split -d -a3 --bytes=500M --filter='gzip > $FILE.gz' - "SYSTEM-bak01.VHD."
# cat "$FILENAME" | split -d -a3 --bytes="$CHUNKSIZE" --filter='gzip > "$FILENAME".gz` - "$FILENAME."

SEQCMD='seq --format=%03g'
if [[ $CHUNKS -gt 999 ]] ; then
	SEQCMD‏='seq -w'
fi

(
for f in `$SEQCMD 0 $CHUNKS` ; do
	[[ "$f" =~ ^0*([0-9]+)$ ]] && f_num=${BASH_REMATCH[1]}

	CHUNKFILE="$TARGETDIR/"`basename "$FILENAME"`".$f"

	if [[ ${f_num} -lt "$CHUNKSTART" ]] ; then
		continue
	fi
	if [ "$CHUNKEND" != "all" ] ; then
		if [ ${f_num} -gt "$CHUNKEND" ] ; then
			break
		fi
	fi

	echo "$f:"
#	echo $'\t'dd if=\""$FILENAME"\" of=\""$CHUNKFILE"\" bs=$CHUNKSIZE skip=$f count=1
	echo $'\t'dd if=\""$FILENAME"\" bs=$CHUNKSIZE skip=${f_num} count=1 "| gzip >" \""$CHUNKFILE".gz\" 
done

echo -n "all:"
for f in `$SEQCMD 0 $CHUNKS` ; do
	[[ "$f" =~ ^0*([0-9]+)$ ]] && f_num=${BASH_REMATCH[1]}

	if [[ ${f_num} -lt "$CHUNKSTART" ]] ; then
		continue
	fi
	if [ "$CHUNKEND" != "all" ] ; then
		if [ ${f_num} -gt "$CHUNKEND" ] ; then
			break
		fi
	fi

	echo -n " $f"
done
echo
) > "$MAKEFILE"

if [ "$DRYRUN" == 1 ] ; then
	cat "$MAKEFILE"
else
	make -f "$MAKEFILE" -j`nproc` all
fi

#===
# cleanup

rm -f "$MAKEFILE"
