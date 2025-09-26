`ifndef FIFO_RST_MON__SV
`define FIFO_RST_MON__SV


class fifo_rst_mon;
event reset_e_w,reset_e_r;
virtual my_if my_if6;
task run();
fork
  mon_reset();
join_none
endtask

task mon_reset();
  fork
  forever begin
  @(negedge my_if6.wrst_n);
  ->reset_e_w;
  end
  forever begin
  @(negedge my_if6.rrst_n);
  ->reset_e_r;
  end

  join
endtask

function new(event reset_e_w,reset_e_r);
   this.reset_e_w = reset_e_w;
   this.reset_e_r = reset_e_r;
endfunction

endclass

`endif
