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
//               message queue produced by long_pkt.c and forwards each
//               payload word to the spad on tile 8 via mPut, so the
//               values land in that spad's dp_ram and are dumped to
//               tile_01.dat for check_long_pkt.sh.
//
// Queue read protocol:
//   - qWait(q, tmp) blocks until the queue head is valid. It peeks the
//     head word but does NOT advance the read pointer.
//   - qGet(q, dst)  returns the head word and advances the read pointer
//     by one (the actual "pop").
//
// This file mirrors long_pkt.c's send sequence call-for-call, so the
// receive side never needs to decode the binary header fields at
// runtime -- it just knows, from the sender's fixed structure, how
// many words each call produced and what to do with them:
//
//   long_pkt.c call         FIFO words produced      recv_pkt.c mirror
//   ----------------------  -----------------------  --------------------------
//   qPut(dest, data1)       [header, data1]           qGetPut(&data1)
//   qPutH(dest, code)       [long-header, 0x0]         qGetPutH()
//   qPutD(data1, data2)     [data1, data2]             qGetPutD(&data1, &data2)
//
// Header / filler words are popped and discarded (not forwarded); only
// the real payload words (the values long_pkt.c actually computed) are
// forwarded via mPut. That is exactly:
//   - qPut:            1 call  -> 1 payload word  (0xcafecafe)
//   - qPutH+qPutD x1:  1 call  -> 2 payload words
//   - qPutH+qPutD x2:  1 call  -> 4 payload words
//   - qPutH+qPutD x4:  1 call  -> 8 payload words
//   - qPutH+qPutD x8:  1 call  -> 16 payload words
//   - qPutH+qPutD x16: 1 call  -> 32 payload words
//   Total payload words  = 1 + 2 + 4 + 8 + 16 + 32 = 63
//   (32 words from the data1/cafe chain, 31 from the data2/baca chain)
//
// Total FIFO words actually popped from the queue (payload + the
// header/filler words that come with each qPut/qPutH call):
//   - 1 qPut     x 2 words           =  2
//   - 5 qPutH    x 2 words           = 10
//   - 31 qPutD   x 2 words           = 62
//   ---------------------------------------
//   Total                            = 74 words popped via qGet
// ////////////////////////////////////////////////////////////////

#include <stdlib.h>
#include "mq.h"

//- Source queue id (local inbound queue)
#define SRC_Q 0

void qGetWait(uint32_t *data);
void qGetPut(uint32_t *data);
void qGetPutH(void);
void qGetPutD(uint32_t *data1, uint32_t *data2);
void mPutAddrInc(uint32_t data, uint32_t *addr);
uint32_t addr_calc(uint32_t destination_tile_id, uint32_t local_tile_id);

void main (){

  uint32_t addr;
  uint32_t local_tile_id;         //- This tile's id (9)
  uint32_t destination_tile_id;   //- The spad's id (8)
  uint32_t data1, data2;

  //- we are tile 9
  local_tile_id = 9;
  //- we want to send it to the SPAD on tile 8
  destination_tile_id = 8;

  addr = addr_calc(destination_tile_id, local_tile_id);

  //- Mirror: qPut(dest_tile, data1) -> [header, data1]
  qGetPut(&data1);
  mPutAddrInc(data1, &addr);

  //- Mirror: pkt_sz_code=1; qPutH(dest_tile,1); qPutD(data1,data2);
  qGetPutH();
  qGetPutD(&data1, &data2);
  mPutAddrInc(data1, &addr);
  mPutAddrInc(data2, &addr);

  //- Mirror: pkt_sz_code=2; qPutH(dest_tile,2); 2x qPutD(...)
  qGetPutH();
  for (int i=0; i<2; i=i+1){
    qGetPutD(&data1, &data2);
    mPutAddrInc(data1, &addr);
    mPutAddrInc(data2, &addr);
  }

  //- Mirror: pkt_sz_code=3; qPutH(dest_tile,3); 4x qPutD(...)
  qGetPutH();
  for (int i=0; i<4; i=i+1){
    qGetPutD(&data1, &data2);
    mPutAddrInc(data1, &addr);
    mPutAddrInc(data2, &addr);
  }

  //- Mirror: pkt_sz_code=4; qPutH(dest_tile,4); 8x qPutD(...)
  qGetPutH();
  for (int i=0; i<8; i=i+1){
    qGetPutD(&data1, &data2);
    mPutAddrInc(data1, &addr);
    mPutAddrInc(data2, &addr);
  }

  //- Mirror: pkt_sz_code=5; qPutH(dest_tile,5); 16x qPutD(...)
  qGetPutH();
  for (int i=0; i<16; i=i+1){
    qGetPutD(&data1, &data2);
    mPutAddrInc(data1, &addr);
    mPutAddrInc(data2, &addr);
  }

}

//- Blocks until the queue head is valid (qWait), then pops it (qGet).
void qGetWait(uint32_t *data) {
  uint32_t tmp;   //- Throwaway for qWait peek
  qWait(SRC_Q, tmp);      //- block until head word is valid
  qGet(SRC_Q, *data);     //- pop head word
}

//- Mirrors a short qPut(dest, data): pops [header, data] and returns
//- only the actual data word (the header is discarded).
void qGetPut(uint32_t *data) {
  uint32_t header;
  qGetWait(&header);   //- discard header
  qGetWait(data);       //- real payload word
}

//- Mirrors a qPutH(dest, code): pops [long-header, 0x0 filler] and
//- discards both (the receiver already knows the packet-size sequence
//- from mirroring long_pkt.c's structure, so it doesn't need to decode
//- the header's embedded size code).
void qGetPutH(void) {
  uint32_t header1;
  uint32_t filler;
  qGetWait(&header1);
  qGetWait(&filler);
}

//- Mirrors a qPutD(data1, data2): pops the two payload words directly.
void qGetPutD(uint32_t *data1, uint32_t *data2) {
  qGetWait(data1);
  qGetWait(data2);
}

//- Forwards a received payload word to the spad via mPut, then
//- advances the destination address by one word.
void mPutAddrInc (uint32_t data, uint32_t *addr) {
  mPut(data, *addr);
  *addr = *addr + 1;
}

uint32_t addr_calc (uint32_t destination_tile_id, uint32_t local_tile_id) {
  //- Declare variables for address calculation
  uint32_t destination_tile_id_s;
  uint32_t local_tile_id_s;

  uint32_t mem_location;
  uint32_t remote_mem_location1;
  uint32_t remote_mem_address1;

  local_tile_id_s = local_tile_id << 12; // shift for hardware
  destination_tile_id_s = destination_tile_id << 12; // shift for hardware

  mem_location = 1024 + (local_tile_id*180);

  remote_mem_location1 = mem_location; //+mem_offset_remote;
  remote_mem_address1  = remote_mem_location1+destination_tile_id_s; // Real memory location

  return remote_mem_address1;
}
