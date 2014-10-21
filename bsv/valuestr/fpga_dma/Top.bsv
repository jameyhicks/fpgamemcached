// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import PortalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;
import HostInterface::*;

// generated by tool
import SimpleIndicationProxy::*;
import SimpleRequestWrapper::*;
import DmaDebugRequestWrapper::*;
import MMUConfigRequestWrapper::*;
import DmaDebugIndicationProxy::*;
import MMUConfigIndicationProxy::*;

// defined by user
import Simple::*;

import DRAMController::*;

`ifdef BSIM
import DDR3Sim::*;
`else
import Clocks          :: *;
import DefaultValue    :: *;
import XilinxVC707DDR3::*;
import Xilinx       :: *;
import XilinxCells ::*;
`endif 



import ChipscopeWrapper ::*;

typedef enum {SimpleIndication, SimpleRequest, HostDmaDebugIndication, HostDmaDebugRequest, HostMMUConfigRequest, HostMMUConfigIndication} IfcNames deriving (Eq,Bits);

`ifdef BSIM
typedef StdPortalDmaTop#(PhysAddrWidth) PortalTopIfc;
`else
typedef PortalTop#(PhysAddrWidth, 64, DDR3_Pins_VC707, 1) PortalTopIfc;
`endif

module mkPortalTop#(HostType host)(PortalTopIfc);
   
   `ifdef BSIM
   let ddr3_ctrl_user <- mkDDR3Simulator;
   `else
   Clock sys_clk = host.tsys_clk_200mhz;
   Reset pci_sys_reset_n <- mkAsyncResetFromCR(1, sys_clk); 
   
   ClockGenerator7Params clk_params = defaultValue();
   clk_params.clkin1_period     = 5.000;       // 200 MHz reference
   clk_params.clkin_buffer      = False;       // necessary buffer is instanced above
   clk_params.reset_stages      = 0;           // no sync on reset so input clock has pll as only load
   clk_params.clkfbout_mult_f   = 5.000;       // 1000 MHz VCO
   clk_params.clkout0_divide_f  = 10;          // unused clock 
   //clk_params.clkout0_divide_f  = 8;//10;          // unused clock 
   clk_params.clkout1_divide    = 5;           // ddr3 reference clock (200 MHz)

   ClockGenerator7 clk_gen <- mkClockGenerator7(clk_params, clocked_by sys_clk, reset_by pci_sys_reset_n);
   Clock ddr_clk = clk_gen.clkout0;
   Reset rst_n <- mkAsyncReset( 1, pci_sys_reset_n, ddr_clk );
   Reset ddr3ref_rst_n <- mkAsyncReset( 1, rst_n, clk_gen.clkout1 );
   //Reset ddr3ref_rst_n <- mkAsyncReset( 1, pci_sys_reset_n, clk_gen.clkout1 );

   DDR3_Configure ddr3_cfg = defaultValue;
   ddr3_cfg.reads_in_flight = 32;   // adjust as needed
   //ddr3_cfg.reads_in_flight = 24;   // adjust as needed
   //ddr3_cfg.fast_train_sim_only = False; // adjust if simulating
   //Clock ddr_buf <- mkClockBUFG(clocked_by clk_gen.clkout1);
   Clock ddr_buf = clk_gen.clkout1;
   DDR3_Controller_VC707 ddr3_ctrl <- mkDDR3Controller_VC707(ddr3_cfg, ddr_buf, clocked_by ddr_buf, reset_by ddr3ref_rst_n);
   
   Clock ddr3clk = ddr3_ctrl.user.clock;
   Reset ddr3rstn = ddr3_ctrl.user.reset_n;
   
   `endif
     
   
   DRAMControllerIfc dramController <- mkDRAMController();
   
   `ifdef BSIM
   let ddr_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), clockOf(ddr3_ctrl_user), resetOf(ddr3_ctrl_user));
   mkConnection(ddr_cli_200Mhz, ddr3_ctrl_user);
   `else
   let ddr_cli_200Mhz <- mkDDR3ClientSync(dramController.ddr3_cli, clockOf(dramController), resetOf(dramController), ddr3clk, ddr3rstn);
   mkConnection(ddr_cli_200Mhz, ddr3_ctrl.user);
   `endif
  

   `ifdef BSIM
   let chipscope <- mkChipscopeEmpty();
   `else
   let chipscope <- mkChipscopeDebug();
   rule doDebug_0;
      chipscope.ila_dram_0.setAddr(dramController.debug.req().address);
      chipscope.ila_dram_0.setWriteen(dramController.debug.req().writeen);
      chipscope.ila_dram_0.setDataIn(dramController.debug.req().datain);
   endrule
   
   rule doDebug_0_1;
      chipscope.ila_dram_0.setDataOut(dramController.debug.resp());
   endrule
   `endif
   
  
   // instantiate user portals
   SimpleIndicationProxy simpleIndicationProxy <- mkSimpleIndicationProxy(SimpleIndication);
   Simple simple <- mkSimple(simpleIndicationProxy.ifc, dramController, chipscope.ila_val_0, chipscope.ila_val_1);
   SimpleRequestWrapper simpleRequestWrapper <- mkSimpleRequestWrapper(SimpleRequest,simple.request);
   
   Vector#(1,  ObjectReadClient#(64))   readClients = cons(simple.dmaReadClient, nil);
   Vector#(1, ObjectWriteClient#(64))  writeClients = cons(simple.dmaWriteClient, nil);
   MMUConfigIndicationProxy hostMMUConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMUConfigIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMUConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMUConfigRequest, hostMMU.request);

   DmaDebugIndicationProxy hostDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostDmaDebugIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServerRW(hostDmaDebugIndicationProxy.ifc, readClients, writeClients, cons(hostMMU,nil));
   DmaDebugRequestWrapper hostDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostDmaDebugRequest, dma.request);

   
   Vector#(6,StdPortal) portals;
   portals[0] = simpleRequestWrapper.portalIfc;
   portals[1] = simpleIndicationProxy.portalIfc;
   portals[2] = hostDmaDebugRequestWrapper.portalIfc;
   portals[3] = hostDmaDebugIndicationProxy.portalIfc; 
   portals[4] = hostMMUConfigRequestWrapper.portalIfc;
   portals[5] = hostMMUConfigIndicationProxy.portalIfc;

   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
   interface leds = default_leds;

   `ifndef BSIM
   interface pins = ddr3_ctrl.ddr3;
   `endif
   
endmodule : mkPortalTop

