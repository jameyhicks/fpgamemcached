SRC_BSV = ../bsv

INTERFACES = SimpleRequest SimpleIndication

BSVFILES = Dut.bsv \
	$(SRC_BSV)/ProtocolHeader.bsv \
	$(SRC_BSV)/arbiter/DRAMArbiter.bsv \
	$(SRC_BSV)/hashtable_optimized/Serializer.bsv \
	Top.bsv \
	../xilinx/aurora_64b66b/AuroraExtImport.bsv \
	AuroraEndpointHelper_Verifier.bsv \
	../lib/AuroraCommon.bsv

CPPFILES = testsimple.cpp
NUMBER_OF_MASTERS = 0
DERIVED_CLOCK_PERIOD=4

BLUEDBMDIR=$(abspath ../../bluedbm)
CONNECTALDIR=$(abspath ../../connectal)
PIN_TYPE=Top_Pins

##		#
##		--xci ~/fpgamemcached/chipscope/ila_dma/ila_dma.xci \

CONNECTALFLAGS = --verilog $(BLUESPECDIR)/lib/board_support/bluenoc/xilinx/VC707/verilog/ddr3_v2_0/ddr3_v2_0/user_design/rtl \
	        --constraint $(BLUEDBMDIR)/xilinx/ddr3_v2_0/vc707_ddr3_sx.xdc \
		--clib rt \
		-D IMPORT_HOSTIF \
		--bscflags " -steps-max-intervals 200000 "

ifeq ($(BOARD), bluesim)
BSVFILES += 	Simple_Verifier.bsv \
		$(SRC_BSV)/hardware_controller/dram_sim/DDR3Sim.bsv \
		$(SRC_BSV)/hardware_controller/dram_sim/raw_64/DRAMController.bsv
else
BSVFILES +=	Simple.bsv \
		$(SRC_BSV)/hardware_controller/dram/raw_64/DRAMController.bsv
CONNECTALFLAGS += 	--verilog ../xilinx/aurora_64b66b/ \
		        --verilog $(BLUEDBMDIR)/xilinx/ddr3_v2_0 \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y25/aurora_64b66b_X1Y25.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y26/aurora_64b66b_X1Y26.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y27/aurora_64b66b_X1Y27.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y16/aurora_64b66b_X1Y16.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y17/aurora_64b66b_X1Y17.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y18/aurora_64b66b_X1Y18.xci \
			--xci $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y19/aurora_64b66b_X1Y19.xci \
			--constraint ../xilinx/aurora_64b66b/aurora_64b66b_exdes.xdc

AURORA_EXTRA = $(CONNECTALDIR)/out/$(BOARD)/aurora_64b66b_X1Y24/aurora_64b66b_X1Y24_stub.v

prebuild:: $(AURORA_EXTRA)

$(AURORA_EXTRA): $(BLUEDBMDIR)/core-scripts/synth-aurora-ext.tcl
	(cd $(BOARD); vivado -mode batch -source $(BLUEDBMDIR)/core-scripts/synth-aurora-ext.tcl)
	find $(CONNECTALDIR)/out/$(BOARD)/ -name "aurora_64b66b_X1Y??_wrapper.v" -exec sed -i "s/GT0_txdiffctrl_in[ \t]\+([4'b10]\+),/GT0_txdiffctrl_in (4'b1100),/g" '{}' \;	

endif

include $(CONNECTALDIR)/Makefile.connectal

