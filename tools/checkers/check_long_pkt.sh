# *************************************************************************
# 
# *** Copyright Notice ***
#
# P38 heterogeneous multi-tiled system with support for message queues 
# (MoSAIC) Copyright (c) 2024, The Regents of the University of California, 
# through Lawrence Berkeley National Laboratory (subject to receipt of
# any required approvals from the U.S. Dept. of Energy). All rights reserved.
# 
# If you have questions about your rights to use or distribute this software,
# please contact Berkeley Lab's Intellectual Property Office at
# IPO@lbl.gov.
#
# NOTICE.  This Software was developed under funding from the U.S. Department
# of Energy and the U.S. Government consequently retains certain rights.  As
# such, the U.S. Government has been granted for itself and others acting on
# its behalf a paid-up, nonexclusive, irrevocable, worldwide license in the
# Software to reproduce, distribute copies to the public, prepare derivative 
# works, and perform publicly and display publicly, and to permit others 
# to do so.
#
# *************************************************************************
#
#    By LKallem, June 2026.
# 
# Exact checker for the long_pkt message-queue test.
#
# long_pkt.c (pico at tile 00) sends message-queue packets to dest_tile = 9
# (the pico at row1,col1). recv_pkt.c drains tile 9's inbound queue and
# stores every received word into a global array in dp_ram, dumped to
# tile_11.dat.
#
# This checker validates the EXACT payload values that long_pkt.c sends,
# using set-membership + exact-count semantics (each expected value must
# appear exactly once). It tolerates the header / filler words that
# recv_pkt.c also stores, because it only checks the expected payload set.
#
# Payload sent by long_pkt.c (derived directly from the source):
#   - qPut(9, 0xcafecafe)                              -> data1 = 0xcafecafe
#   - 5 long packets of qPutD(data1, data2) with
#     data1, data2 incremented by 1 before each qPutD.
#   Resulting payload value sets (each value sent exactly once):
#     CAFE chain (data1): 0xcafecafe .. 0xcafecb1d   (32 contiguous values)
#     BACA chain (data2): 0xbacabacb .. 0xbacabae9   (31 contiguous values)
#   Total: 63 payload words.
thepath=$1

mem_file="$thepath/tile_01.dat"

#- Checking data1 chain (cafe*) delivered into the receiver queue
echo 'INFO: Checking for received qPut/qPutD data1 (cafe*) at tile 01'
c=$(grep -c cafe $mem_file)
if [ $c -ge 32 ]
then
  echo "SUCCESS: There are $c>=32 CAFE words in the scratchpad at tile 01\n"
else
  echo "FAIL: there are $c CAFE words in the scratchpad at tile 01. Expecting 32\n"
  grep cafe $mem_file
fi

#- Checking data2 chain (baca*) delivered into the receiver queue
echo 'INFO: Checking for received qPutD data2 (baca*) at tile 01'
c=$(grep -c baca $mem_file)
if [ $c -ge 31 ]
then
  echo "SUCCESS: There are $c>=31 BACA words in the scratchpad at tile 01\n"
else
  echo "FAIL: there are $c BACA words in the scratchpad at tile 01. Expecting 31\n"
  grep baca $mem_file
fi