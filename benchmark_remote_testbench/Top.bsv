// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import Leds::*;
import MemTypes::*;
import MemPortal::*;
import HostInterface::*;


// generated by tool
import SimpleIndication::*;
import SimpleRequest::*;

// defined by user
`ifdef BSIM
import Simple_Verifier::*;
`else
import Simple::*;
`endif

import DRAMController::*;
import Clocks          :: *;

`ifdef BSIM
import DDR3Sim::*;
`else
import DefaultValue    :: *;
import XilinxVC707DDR3::*;
import Xilinx       :: *;
import XilinxCells ::*;
`endif

import AuroraCommon::*;

typedef enum {SimpleIndication, SimpleRequest} IfcNames deriving (Eq,Bits);

interface Top_Pins;
   //interface Aurora_Pins#(4) aurora_fmc1;
   //interface Aurora_Clock_Pins aurora_clk_fmc1;
         
   interface Vector#(AuroraExtCount, Aurora_Pins#(1)) aurora_ext;
   interface Aurora_Clock_Pins aurora_quad119;
   interface Aurora_Clock_Pins aurora_quad117;
`ifndef BSIM
   interface DDR3_Pins_VC707 pins_ddr3;
`endif
endinterface

module mkConnectalTop#(HostType host)(ConnectalTop#(PhysAddrWidth, 64, Top_Pins, 0));
   Clock clk250 = host.derivedClock;
   Reset rst250 = host.derivedReset;
   
   `ifdef BSIM
   let ddr3_ctrl_user <- mkDDR3Simulator;
   `else 
   Clock clk200 = host.tsys_clk_200mhz_buf;
   Clock ddr_buf = clk200;
   Reset ddr3ref_rst_n <- mkAsyncResetFromCR(4, ddr_buf );
	/////////////////////////////////////////////////////
   
   DDR3_Configure ddr3_cfg = defaultValue;
   ddr3_cfg.reads_in_flight = 2;   // adjust as needed
   //ddr3_cfg.reads_in_flight = 24;   // adjust as needed
   //ddr3_cfg.fast_train_sim_only = False; // adjust if simulating
   //Clock ddr_buf <- mkClockBUFG(clocked_by clk_gen.clkout1);
   //Clock ddr_buf = clk_gen.clkout1;
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
   
   
   
   // instantiate user portals
   SimpleIndicationProxy simpleIndicationProxy <- mkSimpleIndicationProxy(SimpleIndication);
   let hwmain <- mkSimpleRequest(simpleIndicationProxy.ifc, dramController, clk250, rst250);
   SimpleRequestWrapper simpleRequestWrapper <- mkSimpleRequestWrapper(SimpleRequest,hwmain.request);
   
   Vector#(2,StdPortal) portals;
   portals[0] = simpleRequestWrapper.portalIfc;
   portals[1] = simpleIndicationProxy.portalIfc;
   
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = default_leds;
   
   interface Top_Pins pins;    
      interface Aurora_Pins aurora_ext = hwmain.aurora_ext;
      interface Aurora_Clock_Pins aurora_quad119 = hwmain.aurora_quad119;
      interface Aurora_Clock_Pins aurora_quad117 = hwmain.aurora_quad117;
   `ifndef BSIM
      interface DDR3_Pins_VC707 pins_ddr3 = ddr3_ctrl.ddr3;
   `endif
   endinterface
   


endmodule : mkConnectalTop


