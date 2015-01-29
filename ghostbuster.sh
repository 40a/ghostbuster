#!/bin/bash -eu
runpatch()
{
	FILE="$1"
	POS=$(grep -obUaP "\xf8\xff\x4d\x85\xe4\x48\x8d\x50\x21\x0f\x84\x83\x03\x00\x00" "$FILE" | cut -d: -f1)
	if test -z "$POS"; then
		echo "Haystack is missing, aborting..." >&2
		return
	fi
	printf "\xf8\xff\x4d\x85\xe4\x48\x8d\x50\x29\x0f\x84\x83\x03\x00\x00" | dd of="$FILE" bs=1 seek="$POS" conv=notrunc
	#                                         ^^ +sizeof(*h_alias_ptr)
}

detect()
{
	echo "Checking $1..."
	MD5=$(md5sum - < $1 | cut -d' ' -f1)
	if [ "$MD5" = "f3f632e2aa8ad177f56735fd3700d31f" -o "$MD5" = "bf02a9a38618abbd46cc10bdfec1fbca" ]; then
		echo "Vulnerable, patching..."
		runpatch $1
	elif [ "$MD5" = "6e908dd7e69f8617b9158fbaca5b0f71" -o "$MD5" = "a4732590fdd4f9e1c224f79feff7bb2e" ]; then
		echo "Already patched."
	elif [ "$MD5" = "cdd431223b10776be89e4578c76b5946" ]; then
		echo "Non-vulnerable version."
	else
		echo "Unknown version: $MD5."
	fi
}

detect /lib/x86_64-linux-gnu/libc-2.15.so
DELETED=$(grep 'libc-2.15.so (deleted)' /proc/1/maps -m1 || true)
if test -n "$DELETED"; then
	echo "You have a deleted (possibly, unpatched) version of libc."
	BDEV=$(echo "$DELETED" | awk '{print $4}')
	SONODE=$(echo "$DELETED" | awk '{print $5}')
	SONAME=$(echo "$DELETED" | awk '{print $6}')
	BFILE="/tmp/dev-$$-$BDEV"
	BMAJ=${BDEV%:*}
	BMIN=${BDEV#*:}
	mknod $BFILE b $((0x$BMAJ)) $((0x$BMIN))
	rm -f /vuln || true
	echo -e "ln <$SONODE> /vuln\nclose -a\nq" | debugfs -w $BFILE
	echo 2 > /proc/sys/vm/drop_caches
	detect /vuln
	rm -f /vuln
fi
