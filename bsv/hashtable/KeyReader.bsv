import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;
import ClientServer::*;

import Packet::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import HashtableTypes::*;

import BRAMFIFO::*;

typedef enum {Idle, DoRead, ByPass} StateKeyReader deriving (Eq, Bits);

interface KeyReaderIfc;
   method Action start(KeyRdParas hdrRdParas);
   method ActionValue#(HdrWrParas) finish();
   interface Put#(Bit#(64)) inPipe;
   interface Get#(Bit#(64)) outPipe;
   //interface ToHtArbiterIfc currCmd;
   //interface ToPrevModuleIfc prevModule;
   //interface Client#(HtDRAMReq, Bit#(512)) dramEP;
   //interface FIFOF#(HtDRAMReq) cmdQ;
   //interface FIFO#(Bit#(512)) dtaQ;
endinterface

module mkKeyReader#(DRAMReadIfc dramEP)(KeyReaderIfc);
   Reg#(Bool) busy <- mkReg(False);
  
   Reg#(PhyAddr) rdAddr_key <- mkRegU();
   Reg#(Bit#(8)) reqCnt_key <- mkRegU();
    
   FIFO#(Bit#(64)) keyTks <- mkFIFO;
   
   Vector#(NumWays, DepacketIfc#(128, HeaderSz, 0)) depacketEngs_hdr <- replicateM(mkDepacketEngine());
   
   FIFO#(HdrWrParas) immediateQ <- mkFIFO;
   FIFO#(HdrWrParas) finishQ <- mkFIFO;
   
   Reg#(StateKeyReader) state <- mkReg(Idle);
   
   FIFO#(Bit#(64)) keyBuf <- mkSizedFIFO(32);
      
   rule driveRd_data (busy);//(reqCnt > 0);
      if (reqCnt_key > 0) begin
         $display("KeyReader: Sending ReadReq for Data, rdAddr_key = %d", rdAddr_key);
         dramEP.request.put(HtDRAMReq{rnw: True, addr:rdAddr_key, numBytes:64});
         rdAddr_key <= rdAddr_key + 64;
         reqCnt_key <= reqCnt_key - 1;
      end
      else begin
         busy <= False;
      end
   endrule
   
   Vector#(NumWays, PacketIfc#(64, LineWidth, HeaderRemainderSz)) packetEngs_key <- replicateM(mkPacketEngine());
   
   rule procData_2;
      let v <- dramEP.response.get();
      $display("KeyReader: put data in to packetEngs");
      Vector#(NumWays, Bit#(LineWidth)) vector_v = unpack(v);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         packetEngs_key[i].inPipe.put(vector_v[i]);
      end
   endrule
   
   
   FIFO#(StateKeyReader) nextState <- mkFIFO();
   Reg#(Bit#(NumWays)) cmpMask <- mkRegU();
   
   rule doStateSplit (state == Idle);
      let v <- toGet(nextState).get();
      state <= v;
      if ( v == DoRead) begin
         $display("KeyReaders: entering doRead State");
         let args = immediateQ.first();
         cmpMask <= args.cmpMask;
      end
      
   endrule
   
   FIFO#(Bit#(8)) keyMaxQ <- mkFIFO();
   Reg#(Bit#(8)) keyCnt <- mkReg(0);
   rule doRead (state == DoRead);
      Bit#(NumWays) cmpMask_temp = cmpMask;
      let keyMax = keyMaxQ.first();
      if (keyCnt < keyMax ) begin
         let keyToken <- toGet(keyTks).get();
         $display("Comparing keys, keytoken == %h", keyToken);
         keyBuf.enq(keyToken);
         for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
            let key <- packetEngs_key[i].outPipe.get();
            if ( cmpMask[i] == 1 && key != keyToken ) begin
               cmpMask_temp[i] = 0;
            end
         end
         keyCnt <= keyCnt + 1;
      end
      else begin
         keyMaxQ.deq();
         let v <- toGet(immediateQ).get();
         v.cmpMask = cmpMask_temp;
         finishQ.enq(v);
         keyCnt <= 0;
         state <= Idle;
      end
   endrule
   
   rule doBypass (state == ByPass);
      let keyMax = keyMaxQ.first();
      if (keyCnt < keyMax ) begin
         let keyToken <- toGet(keyTks).get();
         $display("Bypassing keys, keytoken == %h", keyToken);
         keyBuf.enq(keyToken);
         keyCnt <= keyCnt + 1;
      end
      else begin
         keyMaxQ.deq();
         keyCnt <= 0;
         state <= Idle;
      end
   endrule
   
   method Action start(KeyRdParas args) if (!busy);
      $display("KeyReader start: keyAddr = %d, keyNreq = %d", args.keyAddr, args.keyNreq);
      rdAddr_key <= args.keyAddr;
      reqCnt_key <= args.keyNreq;

      Bit#(8) numKeytokens;

      if ( (args.keyLen & 7) == 0 ) begin
         numKeytokens = args.keyLen >> 3;
      end
      else begin
         numKeytokens = (args.keyLen >> 3) + 1;
      end
   
      if (args.cmpMask == 0) begin
         nextState.enq(ByPass);
         finishQ.enq(HdrWrParas{hv: args.hv,
                                idx: args.idx,
                                hdrAddr: args.hdrAddr,
                                hdrNreq: args.hdrNreq,
                                keyAddr: args.keyAddr,
                                keyNreq: args.keyNreq,
                                keyLen: args.keyLen,
                                nBytes: args.nBytes,
                                time_now: args.time_now,
                                cmpMask: args.cmpMask,
                                idleMask: args.idleMask,
                                oldHeaders: args.oldHeaders});
      end
      else begin
         for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
            packetEngs_key[i].start(extend(args.keyNreq), extend(numKeytokens));
         end
         dramEP.start(args.hv, args.idx, extend(args.keyNreq));
         
         nextState.enq(DoRead);
         busy <= True;
         immediateQ.enq(HdrWrParas{hv: args.hv,
                                   idx: args.idx,
                                   hdrAddr: args.hdrAddr,
                                   hdrNreq: args.hdrNreq,
                                   keyAddr: args.keyAddr,
                                   keyNreq: args.keyNreq,
                                   keyLen: args.keyLen,
                                   nBytes: args.nBytes,
                                   time_now: args.time_now,
                                   cmpMask: args.cmpMask,
                                   idleMask: args.idleMask,
                                   oldHeaders: args.oldHeaders});
      end
      keyMaxQ.enq(numKeytokens);
    
   endmethod
   
   method ActionValue#(HdrWrParas) finish();
      let v <- toGet(finishQ).get();
      return v;
   endmethod
   
   interface Put inPipe = toPut(keyTks);
   interface Get outPipe = toGet(keyBuf);
 endmodule
