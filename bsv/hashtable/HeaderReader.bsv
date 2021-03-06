import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import ClientServer::*;
import Vector::*;

import Packet::*;
import HtArbiterTypes::*;
import HtArbiter::*;
import HashtableTypes::*;


interface HeaderReaderIfc;
   method Action start(HdrRdParas hdrRdParas);
   method ActionValue#(KeyRdParas) finish();
endinterface

module mkHeaderReader#(DRAMReadIfc dramEP)(HeaderReaderIfc);
   Reg#(Bool) busy <- mkReg(False);
  
   Reg#(PhyAddr) rdAddr_hdr <- mkRegU();
   Reg#(Bit#(8)) reqCnt_hdr <- mkRegU();
  
   Vector#(NumWays, DepacketIfc#(LineWidth, HeaderSz, 0)) depacketEngs_hdr <- replicateM(mkDepacketEngine());
   
   FIFO#(KeyRdParas) immediateQ <- mkSizedFIFO(16);
   FIFO#(KeyRdParas) finishQ <- mkBypassFIFO;
   
   Reg#(Bit#(32)) hv <- mkRegU();
       
   rule driveRd_header (busy);
      if (reqCnt_hdr > 0 )begin
         $display("HeaderReader: Sending ReadReq for Header, rdAddr_hdr = %d", rdAddr_hdr);
         dramEP.request.put(HtDRAMReq{rnw: True, addr: rdAddr_hdr, numBytes:64});
         rdAddr_hdr <= rdAddr_hdr + 64;
         reqCnt_hdr <= reqCnt_hdr - 1;
      end
      else begin
         busy <= False;
      end
   endrule
        
   rule procHeader_2;
      $display("HeaderReader: Putting data into depacketEngs");
      let v <- dramEP.response.get();
      Vector#(NumWays, Bit#(LineWidth)) vector_v = unpack(v);
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         depacketEngs_hdr[i].inPipe.put(vector_v[i]);
      end
   endrule
   
   rule procHeader_3;
      Vector#(NumWays, ItemHeader) headers;
      Bit#(NumWays) cmpMask_temp = 0;
      Bit#(NumWays) idleMask_temp = 0;
      
      let args <- toGet(immediateQ).get();
      
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         let v_ <- depacketEngs_hdr[i].outPipe.get;
         ItemHeader v = unpack(v_);
         headers[i] = v;
         if (v.idle != 0 ) begin
            idleMask_temp[i] = 1;
         end
         else if (v.keylen == args.keyLen ) begin
            cmpMask_temp[i] = 1;
         end
      end
      
      let idx <- dramEP.getReqId();
      args.idx = idx;
      args.cmpMask = cmpMask_temp;
      args.idleMask = idleMask_temp;
      args.oldHeaders = headers;
      
      finishQ.enq(args);
      
   endrule
   
   Reg#(Bit#(64)) cnt <- mkReg(0);
   
   FIFO#(Bool) depacketQ <- mkSizedFIFO(32);
   
   rule doDepacket;
      let v <- toGet(depacketQ).get();
      
      for (Integer i = 0; i < valueOf(NumWays); i=i+1) begin
         depacketEngs_hdr[i].start(1, fromInteger(valueOf(HeaderTokens)));
      end
   endrule
   
      
   method Action start(HdrRdParas args) if (!busy);
      $display("Header Reader Starts for hv = %h, ReqCnt = %d", args.hv, cnt);
      cnt <= cnt + 1;
  
      depacketQ.enq(True);
      dramEP.start(args.hv, ?, extend(args.hdrNreq));
      hv <= args.hv;
      rdAddr_hdr <= args.hdrAddr;
      reqCnt_hdr <= args.hdrNreq;
      busy <= True;
      
      immediateQ.enq(KeyRdParas{hv: args.hv,
                                idx: ?,
                                hdrAddr: args.hdrAddr,
                                hdrNreq: args.hdrNreq,
                                keyAddr: args.keyAddr,
                                keyNreq: args.keyNreq,
                                keyLen: args.keyLen,
                                nBytes: args.nBytes,
                                time_now: args.time_now,
                                cmpMask: ?,
                                idleMask: ?,
                                oldHeaders: ?});
   endmethod
   
   method ActionValue#(KeyRdParas) finish();
      let v <- toGet(finishQ).get();
      return v;
   endmethod

endmodule
