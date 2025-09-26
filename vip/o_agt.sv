`ifndef O_AGT__SV
`define O_AGT__SV
`include "./vip/my_driver.sv"
`include "./vip/out_monitor.sv"
`include "./vip/my_sequencer.sv"
class o_agt extends uvm_agent;
    out_monitor mon;
    
    my_driver drv;

    my_sequencer sqr;
 
    uvm_analysis_port #(my_transaction) ap;

    function new(string name = "o_agt", uvm_component parent = null);
        super.new(name,parent);
    endfunction
  
    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);
    
    `uvm_component_utils(o_agt)
endclass

function void o_agt::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(is_active == UVM_ACTIVE) begin
    drv = my_driver::type_id::create("drv",this);
    sqr = my_sequencer::type_id::create("my_sequencer",this); 
    end
    mon = out_monitor::type_id::create("mon",this);
endfunction

function void o_agt::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ap = mon.ap;
endfunction
`endif
