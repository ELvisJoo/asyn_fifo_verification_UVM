`ifndef MY_DRIVER__SV
`define MY_DRIVER__SV

`include "./vip/my_transaction.sv"
class my_driver extends uvm_driver#(my_transaction);

   virtual interface my_if my_if2;
     
   `uvm_component_utils(my_driver)

   covergroup cov_label;
      option.per_instance = 1;
      option.auto_bin_max = 2;
   coverpoint my_if2.wfull;      
   coverpoint my_if2.rempty;
      
   endgroup

   function new(string name = "my_driver", uvm_component parent = null);
      super.new(name,parent);
      cov_label = new();
   endfunction
   
   virtual function void build_phase(uvm_phase phase);
   super.build_phase(phase);
   if(!uvm_config_db#(virtual my_if)::get(this,"","vif",my_if2))
     `uvm_fatal("my_driver","virtual interface must be set for vif!!!")
   endfunction
 
   extern task main_phase(uvm_phase phase);
   extern task drive_one_pkt(my_transaction tr);
endclass 

task my_driver::main_phase(uvm_phase phase);
    `uvm_info("my_driver","begin!",UVM_LOW)
   // phase.raise_objection(this);
   //my_if2.winc = 1;
   //my_if2.rinc = 1;
   
     
   while(1) begin     
     seq_item_port.get_next_item(req);
     drive_one_pkt(req);
     seq_item_port.item_done();
   end    
   
   //repeat(100) @(posedge my_if2.wclk);
  // phase.drop_objection(this);
    
endtask

task my_driver::drive_one_pkt(my_transaction tr);
   byte unsigned data_q[];
   int data_size,j;
   
   data_size = tr.pack_bytes(data_q)/8;
   
   `uvm_info("my_driver","begin to drive one pkt",UVM_LOW)
   for(int i = 0; i < data_size; i++) begin
      @my_if2.ckw;
      if((!my_if2.ckw.wfull) && (my_if2.ckw.winc == 1)) begin 
         cov_label.sample(); 
         my_if2.ckw.wdata <= data_q[i];
         `uvm_info("my_driver",$sformatf("%0d number is sent,number is %0h",j++,my_if2.ckw.wdata),UVM_LOW) 
      end  else if((!my_if2.ckw.wfull) && (my_if2.ckw.winc == 0)) begin
            my_if2.ckw.winc <= 1;
            i--;
         end else begin
            my_if2.ckw.winc <= 0;
            i--;
         end
      end  
endtask
`endif


  /* bit  [47 : 0] tmp_data;
   bit  [7 : 0] data_q[$];
   int  j;
   
  //push dmac to data_q
  tmp_data = tr.dmac;
  for(int i = 0; i < 6; i++) begin
     data_q.push_back(tmp_data[7 : 0]);
     tmp_data = ( tmp_data >> 8 );
  end
   
  tmp_data = tr.smac;
  //push smac to data_q
  for(int i = 0; i < 6; i++) begin
     data_q.push_back(tmp_data[7 : 0]);
     tmp_data = ( tmp_data >> 8 );
  end
  
  //push ether_type to data_q
   tmp_data = tr.ether_type;
  for(int i = 0; i < 2; i++) begin
     data_q.push_back(tmp_data[7 : 0]);
     tmp_data = ( tmp_data >> 8 );
  end

  //push payload to data_q
  for(int i = 0; i < 200; i++) begin
     data_q.push_back(tr.pload[i] );
  end

  //push crc to data_q
  tmp_data = tr.crc;
  for(int i = 0; i < 4; i++) begin
     data_q.push_back(tmp_data[7 : 0]);
     tmp_data = ( tmp_data >> 8);
  end
  
  my_if2.rinc = 1;
  
  `uvm_info("my_driver","begin to drive one pkt",UVM_LOW)
  repeat(3) @(posedge my_if2.wclk);
  
  //int i = 1;
  while(data_q.size() > 0) begin
     wait(!my_if2.wfull) begin
     repeat(2) @(posedge my_if2.wclk);
     my_if2.wdata = data_q.pop_front();
     `uvm_info("my_driver",$sformatf("%0d number is sent,number is %0h",j++,my_if2.wdata),UVM_LOW)
     end
end
*/

/* for(int i = 0; i < 2; i++) begin
    req = new("req");
    assert(req.randomize() with {pload.size == 200;});
    drive_one_pkt(req);
   end
*/



















