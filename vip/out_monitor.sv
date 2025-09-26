`ifndef OUT_MONITOR__SV
`define OUT_MONITOR__SV

class out_monitor extends uvm_monitor;
    
    virtual my_if my_if4;
   
    uvm_analysis_port#(my_transaction) ap;
    
    `uvm_component_utils(out_monitor);
    function new(string name = "out_monitor", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual my_if)::get(this,"","vif",my_if4))
        `uvm_fatal("out_monitor","virtual interface must be set for vif!!!")
        ap = new("ap",this);
    endfunction

    extern virtual task main_phase(uvm_phase phase);
    extern virtual task collect_one_pkt(my_transaction tr);
endclass

task out_monitor::main_phase(uvm_phase phase);
    my_transaction tr;
    repeat(2) begin
    tr = new("tr");
    collect_one_pkt(tr);
    ap.write(tr);
    end
endtask

task out_monitor::collect_one_pkt(my_transaction tr);
   byte unsigned data_q[$],data_array[];
   int  data_size,k,l;
   `uvm_info("out_monitor","begin to collect one pkt",UVM_LOW)    
    while(1) begin
        @my_if4.ckom;
        if((!my_if4.ckom.rempty) && (my_if4.ckom.rinc == 1)) begin       
        data_q.push_back(my_if4.ckom.rdata);        
        `uvm_info("out_monitor",$sformatf("%0d number is received,number is %0h",k++,my_if4.ckom.rdata),UVM_LOW)
        if(l == 217) break;
        //@(my_if4.rdata);
        l++;
        end else if((!my_if4.ckom.rempty) && (my_if4.ckom.rinc == 0)) begin
        my_if4.ckom.rinc <= 1;
        end else begin
          my_if4.ckom.rinc <= 0;                  
        end        
    end
    
    data_size = data_q.size();
    data_array = new[data_size];
    for(int i = 0; i < data_size; i++) begin
        data_array[i] = data_q[i];
    end
    tr.pload = new[data_size - 18];
    data_size = tr.unpack_bytes(data_array) / 8;
    `uvm_info("out_monitor","end collect one pkt",UVM_LOW)
    tr.print();  

 
endtask
`endif

/* bit [7 : 0] data_q[$];
    int psize;
    int k,l;

    `uvm_info("out_monitor","begin to collect one pkt",UVM_LOW)    
    while(my_if4.rinc) begin
        data_q.push_back(my_if4.rdata);
        `uvm_info("out_monitor",$sformatf("%0d number is received,number is %0h",k++,my_if4.rdata),UVM_LOW)
        if(l == 213) break;
        @(my_if4.rdata);
        l++;        
    end
   
    
  //pop dmac
   for(int i = 0; i < 6; i++) begin
      tr.dmac = {tr.dmac[ 39 : 0] ,data_q.pop_front()};
   end

   //pop smac
   for(int i = 0; i < 6; i++) begin
      tr.smac = {tr.smac[ 39 : 0] , data_q.pop_front()};
   end

   //pop ether_type
   for(int i = 0; i < 2; i++) begin
      tr.ether_type = {tr.ether_type[ 7 : 0] , data_q.pop_front()};
   end

   //pop payload
   for(int i = 0; i < 200; i++) begin
      tr.pload[i] = data_q.pop_front();
   end

   //pop crc
   for(int i = 0; i < 4; i++) begin
      tr.crc = {tr.crc[ 23 : 0] ,data_q.pop_front()};  
   end
   `uvm_info("out_monitor","end collect one pkt, print it",UVM_LOW)
   tr.print();
*/


