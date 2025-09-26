`ifndef FIFO_CHK_RST__SV
`define FIFO_CHK_RST__SV

 
class fifo_chk_rst;
bit en_chk_rst = 1;
event reset_e_w,reset_e_r;
virtual my_if my_if7;


function new(event reset_e_w, reset_e_r);
  this.reset_e_w = reset_e_w;
  this.reset_e_r = reset_e_r;
endfunction

task run();
  fork 
   chk_rst();
  join_none
endtask

task chk_rst();

  fork
  forever begin
   @(reset_e_w);
   if(en_chk_rst) begin
    $display("%b",my_if7.wfull);
    
    if(my_if7.wfull !==0)
     $error("fifo_chk_rst: reset_w value is not correct!");
    else 
     $display("fifo_chk_rst: reset_w value is correct!");
   end
  end
 
  forever begin
   @(reset_e_r);
   if(en_chk_rst) begin
    $display("%b",my_if7.rempty);
  
    if(my_if7.rempty !==1)
     $error("fifo_chk_rst: reset_r value is not correct!");
    else 
     $display("fifo_chk_rst: reset_r value is correct!");
   end
  end

  join
endtask
endclass
`endif
