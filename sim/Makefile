#UVM_HOME = /opt/Synopsys/vcs_202003/Q-2020.03-SP2-7/etc/uvm-1.2

#VERDI_HOME =/opt/Synopsys/verdi_202012/R-2020.12-SP1

.PHONY : COMPILE

COMPILE:
	vcs -R -full64 -sverilog -debug_all -fsdb\
 +incdir+$(UVM_HOME)/src \
 $(UVM_HOME)/src/uvm_pkg.sv \
$(UVM_HOME)/src/dpi/uvm_dpi.cc \
-P $(VERDI_HOME)/share/PLI/VCS/LINUXAMD64/novas.tab $(VERDI_HOME)/share/PLI/VCS/LINUXAMD64/pli.a \
 -CFLAGS -DVCS -cm tgl+cond+fsm  -timescale=1ns/1ps  -f filelist.f  +UVM_TESTNAME=my_case0

.PHONY : SIMULATION

SIMULATION:
	./simv -cm tgl+cond+fsm -cm_dir ./run_cov/case1 +UVM_TESTNAME=my_case0

.PHONY : URG

URG:
	urg -full64 -dir /home/autumn/test/fifo_uvm/simv.vdb  -report coverage_report -format both

.PHONY : clean

clean: 
	-rm tr_db.log ucli.key vc_hdrs.h tb.fsdb simv     -r csrc simv.daidir simv.vdb
