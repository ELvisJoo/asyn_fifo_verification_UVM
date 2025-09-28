`ifndef MY_SEQUENCER_SV
`define MY_SEQUENCER_SV
`include "./vip/my_transaction.sv"

class my_sequencer extends uvm_sequencer #(my_transaction);
    `uvm_component_utils(my_sequencer)
  
    function new(string name = "my_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
endclass
`endif