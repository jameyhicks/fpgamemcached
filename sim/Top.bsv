// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import AxiMasterSlave::*;

// generated by tool
import ServerIndicationProxy::*;
import ServerRequestWrapper::*;

// defined by user
//import ProtocolHeader::*;
import MemcachedServer::*;

import DDR3Sim::*;
import DRAMController::*;

typedef enum {ServerIndication, ServerRequest} IfcNames deriving (Eq,Bits);

module mkPortalTop(StdPortalTop#(addrWidth));
   
   let ddr3_ctrl_user <- mkDDR3Simulator;
   
   let dram <- mkDRAMController(ddr3_ctrl_user);

   // instantiate user portals
   ServerIndicationProxy serverIndicationProxy <- mkServerIndicationProxy(ServerIndication);
   ServerRequest serverRequest <- mkServerRequest(serverIndicationProxy.ifc, dram);
   ServerRequestWrapper serverRequestWrapper <- mkServerRequestWrapper(ServerRequest,serverRequest);
   
   Vector#(2,StdPortal) portals;
   portals[0] = serverRequestWrapper.portalIfc; 
   portals[1] = serverIndicationProxy.portalIfc;
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkAxiSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface ctrl = ctrl_mux;
   interface m_axi = null_axi_master;
   interface leds = default_leds;

endmodule : mkPortalTop

