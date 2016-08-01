#! /usr/bin/env bash
##
#    storage_bench.sh, simple bash script to roughly benchmark a mounted storage system.
#    Copyright (C) 2016  ASTRON (Netherlands Foundation for Research in Astronomy)
#    P.O.Box 2, 7990 AA Dwingeloo, The Netherlads, grange@astron.nl
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##


cd /dev/shm # fastest available device
dd if=/dev/urandom bs=1G count=1 of=basefile # large file to make sure it won't be compressible. To save time, we will use this as a base
                                             # urandom is way too slow to use directly for this purpose

for i in `seq 30`                            # 1G file takes 1 minute. To save us from waiting for half an hour, we just copy this one a few times over
do                                           # We assume the OS is not extremely smart and will not notice the repetition (have never seen that happen)
cat basefile >> largefile
done

# Going to use some stuff from Tomi Salminen:
# https://github.com/tlsalmin/vlbi-streamer/blob/master/scripts/test_volumespeeds

CONVFLAGS=fdatasync
FLAGS=direct
BLOCK_SIZE=65536                            # Used the scripts from https://github.com/tdg5/blog/tree/master/_includes/scripts to find that this is more 
                                            # or less an optimum for reading and writing on all devices on the specific system I used this on. 
                                            # I'd love to put a copy of those in my repo but since they aren't licensed, I can't.

MBSIZE=$(ls -l --block-size=M /dev/shm/largefile | awk '{print $5}' | sed -e 's/M//g') # Not a mathematician at heart and hey, if they allow "M", better use it! 
                                                                                       # And I always confuse the SI vs compute prefixes anyway
function wtest {               # read from shm, write to device
    dd if=/dev/shm/largefile of=$1/testfile bs=${BLOCK_SIZE} conv=$CONVFLAGS oflag=$FLAGS &> /dev/null
}
function rtest {               # read from device, write to null
  dd if=$1/testfile of=/dev/null bs=${BLOCK_SIZE} iflag=$FLAGS &> /dev/null
}
function rwtest {              # read from device, write to device
  dd if=$1/testfile bs=${BLOCK_SIZE} of=$1/testfile2 conv=$CONVFLAGS oflag=$FLAGS iflag=$FLAGS &> /dev/null
}

for DEVICE_FOLDER in $*
do
echo "Write to ${DEVICE_FOLDER}"
START=$(date +%s.%N)         # Current time at rediculous precision
    wtest $DEVICE_FOLDER
END=$(date +%s.%N) 
WSPEED=$(echo "$MBSIZE/($END - $START)" | bc -l)

echo "Read from ${DEVICE_FOLDER}"
START=$(date +%s.%N)
    rtest $DEVICE_FOLDER
END=$(date +%s.%N)
RSPEED=$(echo "$MBSIZE/($END - $START)" | bc -l)

echo "Read from & write to ${DEVICE_FOLDER}"
START=$(date +%s.%N)
    rwtest $DEVICE_FOLDER
END=$(date +%s.%N)
RWSPEED=$(echo "$MBSIZE/($END - $START)" | bc -l)

echo "${DEVICE_FOLDER}:"
echo "READ:  ${RSPEED}MB/s"
echo "WRITE: ${WSPEED}MB/s"
echo "R+W:   ${RWSPEED}MB/s"
rm $DEVICE_FOLDER/testfile $DEVICE_FOLDER/testfile2
done
rm /dev/shm/largefile /dev/shm/basefile 
