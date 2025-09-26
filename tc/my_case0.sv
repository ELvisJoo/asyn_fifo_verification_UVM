`ifndef MY_CASE0__SV
`define MY_CASE0__SV

class case0_sequence extends uvm_sequence #(my_transaction);

    my_transaction m_trans;
    
    
    function new(string name = "my_sequence");
        super.new(name);
        //set_automatic_phase_objection(1);
        
    endfunction
    
    virtual task body();
      if(starting_phase != null) begin
      `uvm_info("starting_phase","not null",UVM_LOW)
      starting_phase.raise_objection(this);
      end
     
      
      repeat(2) begin
        `uvm_info("my_sequence","generate one transaction!",UVM_LOW)
        `uvm_do_with(m_trans,{m_trans.pload.size == 200;})        
      end
     
      if(starting_phase != null) begin
      `uvm_info("starting_phase","not null",UVM_LOW)
      starting_phase.drop_objection(this);
      end

    endtask
   
    `uvm_object_utils(case0_sequence)
endclass

class my_case0 extends base_test;

   function new(string name = "my_case0", uvm_component parent = null);
       super.new(name,parent);
   endfunction
   extern virtual function void build_phase(uvm_phase phase);
   extern virtual task main_phase(uvm_phase phase);
   `uvm_component_utils(my_case0)
endclass

function void my_case0::build_phase(uvm_phase phase);
   
     super.build_phase(phase);

     uvm_config_db#(uvm_object_wrapper)::set(this,
                                            "env.i_agt1.sqr.main_phase",
                                            "default_sequence",
                                            case0_sequence::type_id::get());
endfunction

task my_case0::main_phase(uvm_phase phase);
  
  case0_sequence seq;
  phase.raise_objection(this);
  #4;  
  seq = case0_sequence::type_id::create("l_seq");
  `uvm_info("case0_sequence","case0_sequence begin",UVM_LOW)
  seq.start(env.i_agt1.sqr);
  #3000;
  phase.drop_objection(this);
endtask
`endif


    /*uvm_config_db#(uvm_object_wrapper)::set(this,
                                            "env.i_agt1.sqr.main_phase",
                                            "default_sequence",
                                            case0_sequence::type_id::get());
*/

 /*    case0_sequence seq;
     seq = case0_sequence::type_id::create("seq");
      
     uvm_config_db#(uvm_sequence_base)::set(this,
                                            "env.i_agt1.sqr.main_phase",
                                            "default_sequence",
                                            seq); 
*/













