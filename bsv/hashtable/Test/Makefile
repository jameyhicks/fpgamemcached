
S2H = SimpleRequest
H2S = SimpleIndication
DRAMDIR = ../../hardware_controller/dram_sim
BSVFILES =  ../../time/Time.bsv ../Hashtable.bsv ../../valuestr/Valuestr.bsv ../../packet/Packet.bsv\
	$(DRAMDIR)/DDR3Sim.bsv $(DRAMDIR)/raw_64/DRAMController.bsv \
	Simple.bsv Top.bsv
CPPFILES = testsimple.cpp
Dma = 
PINS = Std


XBSVDIR=/home/shuotao/fpgamemcached/xbsv
BOARD=bluesim
TOP=$(XBSVDIR)/bsv/BsimTop
MKTOP=mkBsimTop


build:
	$(XBSVDIR)/genxpsprojfrombsv -B$(BOARD) -p $(BOARD) -x $(MKTOP) \
	$(foreach s2h, $(S2H), -s2h $(s2h)) \
	$(foreach h2s, $(H2S), -h2s $(h2s)) \
	$(foreach f, $(CPPFILES), -s $f) \
	-t $(TOP).bsv $(XBSVFLAGS) $(BSVFILES)

