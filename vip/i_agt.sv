`ifndef I_AGT__SV
`define I_AGT__SV
`include "./vip/my_driver.sv"
`include "./vip/in_monitor.sv"
`include "./vip/my_sequencer.sv"
class i_agt extends uvm_agent;
    my_driver drv;
    in_monitor mon;
    my_sequencer sqr;
   
    uvm_analysis_port #(my_transaction) ap;

    function new(string name = "i_agt", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);
   
    `uvm_component_utils(i_agt)
endclass

function void i_agt::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(is_active == UVM_ACTIVE) begin
    drv = my_driver::type_id::create("a_drv",this);
    sqr = my_sequencer::type_id::create("sqr",this); 
    end
    mon = in_monitor::type_id::create("mon",this);
endfunction

function void i_agt::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
    ap = mon.ap;
endfunction
`endif
