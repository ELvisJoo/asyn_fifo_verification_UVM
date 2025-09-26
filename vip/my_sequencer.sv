`ifndef MY_SEQUENCER__SV
`define MY_SEQUENCER__SV
class my_sequencer extends uvm_sequencer#(my_transaction);
     
    
    
    function new(string name = "my_sequencer",uvm_component parent = null);
        super.new(name,parent);
    endfunction  
    
    task main_phase(uvm_phase phase);
        `uvm_info("my_sequencer","main_phase begin",UVM_LOW)
        
    endtask
   
    
   /*
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(this,
                                          "main_phase",
                                          "default_sequence",
                                           my_sequence::type_id::get()); 
       `uvm_info("default_sequence","has set!",UVM_LOW)
    endfunction
   */

    `uvm_component_utils(my_sequencer)
endclass


`endif

/*
my_sequence seq;
    phase.raise_objection(this);
    seq = my_sequence::type_id::create("seq");
    seq.start(this);
    phase.drop_objection(this);
*/
/*   my_sequence seq;
        phase.raise_objection(this);
        seq = my_sequence::type_id::create("seq");
        seq.start(this);
        phase.drop_objection(this);
*/
