`ifndef MY_ENV__SV
`define MY_ENV__SV
`include "./vip/i_agt.sv"
`include "./vip/o_agt.sv"
`include "./vip/my_model.sv"
`include "./vip/my_scoreboard.sv"
class my_env extends uvm_env;
 
    i_agt i_agt1;
    
    o_agt o_agt1;
   
    my_model mdl;

    my_scoreboard scb;

    uvm_tlm_analysis_fifo#(my_transaction) agt_mdl_fifo;
    uvm_tlm_analysis_fifo#(my_transaction) mdl_scb_fifo;
    uvm_tlm_analysis_fifo#(my_transaction) agt_scb_fifo;
    
    function new(string name = "my_env",uvm_component parent);
        super.new(name,parent); 
    endfunction

   virtual function void build_phase(uvm_phase phase);
       super.build_phase(phase);  
       i_agt1 = i_agt::type_id::create("i_agt1",this);
       o_agt1 = o_agt::type_id::create("o_agt1",this);
       i_agt1.is_active = UVM_ACTIVE;
       o_agt1.is_active = UVM_PASSIVE; mdl = my_model::type_id::create("mdl",this);
       scb = my_scoreboard::type_id::create("scb",this);
       agt_mdl_fifo = new("agt_mdl_fifo",this);
       mdl_scb_fifo = new("mdl_scb_fifo",this);
       agt_scb_fifo = new("agt_scb_fifo",this);
       
       
        
   endfunction
   
   /*virtual function void main_phase(uvm_phase phase);
       i_agt = i_agt::type_id::create("i_agt",this);
       o_agt = o_agt::type_id::create("o_agt",this);
       i_agt.is_active = UVM_ACTIVE;
       o_agt.is_active = UVM_PASSIVE;
   endfunction
*/
    //extern task main_phase(uvm_phase phase);

    extern virtual function void connect_phase(uvm_phase phase);

   `uvm_component_utils(my_env)

endclass

function void my_env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    i_agt1.ap.connect(agt_mdl_fifo.analysis_export);
    mdl.port.connect(agt_mdl_fifo.blocking_get_export);
    mdl.ap.connect(mdl_scb_fifo.analysis_export);
    scb.exp_port.connect(mdl_scb_fifo.blocking_get_export);
    o_agt1.ap.connect(agt_scb_fifo.analysis_export);
    scb.act_port.connect(agt_scb_fifo.blocking_get_export);
endfunction


`endif


/*my_driver drv;

    in_monitor i_mon;

    out_monitor o_mon;
     */


/*drv = my_driver::type_id::create("drv",this);
       i_mon = in_monitor::type_id::create("i_mon",this);
       o_mon = out_monitor::type_id::create("o_mon",this);\
       */

