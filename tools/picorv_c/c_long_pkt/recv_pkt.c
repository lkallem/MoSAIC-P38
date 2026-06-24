// *************************************************************************
// 
// *** Copyright Notice ***
//
// P38 heterogeneous multi-tiled system with support for message queues 
// (MoSAIC) Copyright (c) 2024, The Regents of the University of California, 
// through Lawrence Berkeley National Laboratory (subject to receipt of
// any required approvals from the U.S. Dept. of Energy). All rights reserved.
// 
// If you have questions about your rights to use or distribute this software,
// please contact Berkeley Lab's Intellectual Property Office at
// IPO@lbl.gov.
//
// NOTICE.  This Software was developed under funding from the U.S. Department
// of Energy and the U.S. Government consequently retains certain rights.  As
// such, the U.S. Government has been granted for itself and others acting on
// its behalf a paid-up, nonexclusive, irrevocable, worldwide license in the
// Software to reproduce, distribute copies to the public, prepare derivative 
// works, and perform publicly and display publicly, and to permit others 
// to do so.
//
// *************************************************************************
//
//    By LKallem, June 2026
//
// ////////////////////////////////////////////////////////////////
// Description : Receiver for the long_pkt test. Runs on the
//               destination pico (dest_tile = 9). Drains the inbound
//               message queue produced by long_pkt.c and stores every
//               received word into a global array so that it lands in
//               the tile's dp_ram and is dumped to tile_11.dat for
//               check_long_pkt.sh.
//
//   Queue read protocol (matches send_msg.c / pico_add3.c):
//     - qWait(q, tmp) blocks until the queue head is valid. It peeks
//       the head word but does NOT advance the read pointer.
//     - qGet(q, dst)  returns the head word and advances the read
//       pointer by one (the actual "pop").
//
//   long_pkt.c emits exactly 2 FIFO words per C call, in order:
//     - qPut          -> [header,      0xcafecafe]
//     - qPutH (code N) -> [long-header, 0x0]
//     - qPutD          -> [data1 cafe*, data2 baca*]
//   with N = 1 and 2^(N-1) qPut calls per short packet.
//   with N = 2,3,4,5 and 2^(N-1) qPutD calls per long packet.
//
//   Total words pushed = 1 (one word / short packet) + 2 (1 two word packet) 
//                        + 4 (2 two word packet) + 8 (2 two word packet) 
//                        + 16 (4 two word packet)

//   Of these the data payload is 32 'cafe*' words (data1 chain) + 31
//   'baca*' words (data2 chain). We store ALL 63 words; header / zero
//   words do not contain 'caf' or 'bac', so check_long_pkt.sh still
//   counts exactly 32 'caf' and 31 'bac'.
// ////////////////////////////////////////////////////////////////

#include <stdlib.h>
#include "mq.h"

//- Source queue id (local inbound queue)
#define SRC_Q 0

//- Total number of words pushed into this tile's queue by long_pkt.c.
#define TOTAL_WORDS 63

//- Storage for received words. Declared volatile + global so the
//- compiler keeps it in dp_ram (which is dumped to tile_11.dat).
volatile uint32_t recv_buf[TOTAL_WORDS];

void main (){

  uint32_t tmp;   //- Throwaway for qWait peek

  //- Drain every word. qWait blocks until the head is valid, then
  //- qGet pops it into recv_buf. Doing qWait before each qGet
  //- guarantees we never pop ahead of the producer.
  for (int i = 0; i < TOTAL_WORDS; i = i + 1){
    qWait(SRC_Q, tmp);            //- block until head word is valid
    qGet(SRC_Q, recv_buf[i]);     //- pop head word into dp_ram
  }

}
