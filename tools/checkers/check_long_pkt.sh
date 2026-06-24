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
mem_file="$thepath/tile_11.dat"

#- Expected exact value ranges (inclusive), derived from long_pkt.c
CAFE_LO=$((0xcafecafe)); CAFE_HI=$((0xcafecb1d))   #- 32 values
BACA_LO=$((0xbacabaca)); BACA_HI=$((0xbacabae8))   #- 31 values

if [ ! -f "$mem_file" ]; then
  echo "FAIL: dump file not found: $mem_file"
  exit 0
fi

awk -v cafe_lo="$CAFE_LO" -v cafe_hi="$CAFE_HI" \
    -v baca_lo="$BACA_LO" -v baca_hi="$BACA_HI" '
function hex2dec(s,   v, i, c, d) {
  v = 0
  s = tolower(s)
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    d = index("0123456789abcdef", c) - 1
    if (d < 0) return -1
    v = v * 16 + d
  }
  return v
}
BEGIN { FAIL = 0 }
{
  #- Strip $writememh address comments and any inline comments
  line = $0
  sub(/\/\/.*/, "", line)
  #- Each remaining whitespace-separated token should be a hex word
  n = split(line, toks, /[ \t\r]+/)
  for (k = 1; k <= n; k++) {
    w = toks[k]
    if (w == "") continue
    if (w !~ /^[0-9a-fA-F]+$/) continue
    d = hex2dec(w)
    if (d < 0) continue
    seen[d]++
  }
}
END {
  #- ---- CAFE chain (data1) ----
  exp_cafe = cafe_hi - cafe_lo + 1
  miss_cafe = 0; dup_cafe = 0; ok_cafe = 0
  for (v = cafe_lo; v <= cafe_hi; v++) {
    c = (v in seen) ? seen[v] : 0
    if (c == 0)      { miss_cafe++; printf("  MISSING  CAFE word 0x%08x\n", v) }
    else if (c > 1)  { dup_cafe++;  ok_cafe++; printf("  DUPLICATE CAFE word 0x%08x (x%d)\n", v, c) }
    else             { ok_cafe++ }
  }
  printf("INFO: CAFE chain (data1) 0x%08x..0x%08x: expected %d, found %d, missing %d, duplicated %d\n",
         cafe_lo, cafe_hi, exp_cafe, ok_cafe, miss_cafe, dup_cafe)
  if (miss_cafe == 0 && dup_cafe == 0)
    printf("SUCCESS: All %d CAFE payload words present exactly once at tile 11\n", exp_cafe)
  else { printf("FAIL: CAFE payload mismatch at tile 11\n"); FAIL = 1 }

  #- ---- BACA chain (data2) ----
  exp_baca = baca_hi - baca_lo + 1
  miss_baca = 0; dup_baca = 0; ok_baca = 0
  for (v = baca_lo; v <= baca_hi; v++) {
    c = (v in seen) ? seen[v] : 0
    if (c == 0)      { miss_baca++; printf("  MISSING  BACA word 0x%08x\n", v) }
    else if (c > 1)  { dup_baca++;  ok_baca++; printf("  DUPLICATE BACA word 0x%08x (x%d)\n", v, c) }
    else             { ok_baca++ }
  }
  printf("INFO: BACA chain (data2) 0x%08x..0x%08x: expected %d, found %d, missing %d, duplicated %d\n",
         baca_lo, baca_hi, exp_baca, ok_baca, miss_baca, dup_baca)
  if (miss_baca == 0 && dup_baca == 0)
    printf("SUCCESS: All %d BACA payload words present exactly once at tile 11\n", exp_baca)
  else { printf("FAIL: BACA payload mismatch at tile 11\n"); FAIL = 1 }

  #- ---- Summary ----
  total_exp = exp_cafe + exp_baca
  total_ok  = ok_cafe + ok_baca - dup_cafe - dup_baca
  if (FAIL == 0)
    printf("SUCCESS: Verified %d/%d payload words exactly once (%d CAFE + %d BACA)\n",
           total_exp, total_exp, exp_cafe, exp_baca)
  else
    printf("FAIL: long_pkt payload verification FAILED (%d CAFE + %d BACA expected)\n",
           exp_cafe, exp_baca)
}
' "$mem_file"
