`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "./vip/my_driver.sv"
`include "./vip/my_if.sv"
`include "./vip/my_transaction.sv"
`include "./vip/my_env.sv"
`include "./vip/in_monitor.sv"
`include "./vip/out_monitor.sv"
`include "./vip/i_agt.sv"
`include "./vip/o_agt.sv"
`include "./vip/my_model.sv"
`include "./vip/my_scoreboard.sv"
`include "./vip/my_sequencer.sv"
`include "./vip/base_test.sv"
`include "./vip/fifo_rst_mon.sv"
`include "./vip/fifo_chk_rst.sv"
`include "./tc/my_case0.sv"
`include "./tc/my_case1.sv"
									
module top_tb;
logic wclk,rclk,wrst_n,rrst_n;

my_if my_if1(wclk,rclk,wrst_n,rrst_n);
//my_if.DUT my_if9();

fifo_rst_mon fifo_rst_mon1;
fifo_chk_rst fifo_chk_rst1;
event reset_e_w;
event reset_e_r;

initial begin   
    run_test();
end


initial
begin
wclk = 0;
rclk = 0;
wrst_n = 1;
rrst_n = 1;
#2 wrst_n = 0;
   rrst_n = 0;
   my_if1.winc = 0;
   my_if1.rinc = 0;
#2 wrst_n = 1;
   rrst_n = 1;
//#3 my_if1.winc = 0;
//#1 my_if1.rinc = 0;
//#3 my_if1.winc = 1;
//#4 my_if1.rinc = 1;
end

always #1 wclk = ~wclk;
always #3 rclk = ~rclk;

initial begin
  uvm_config_db#(virtual my_if)::set(null,"uvm_test_top.env.i_agt1.a_drv","vif",my_if1);
  uvm_config_db#(virtual my_if)::set(null,"uvm_test_top.env.i_agt1.mon","vif",my_if1);
  uvm_config_db#(virtual my_if)::set(null,"uvm_test_top.env.o_agt1.mon","vif",my_if1);
  
end

initial begin
fifo_rst_mon1 = new(reset_e_w,reset_e_r);
fifo_chk_rst1 = new(reset_e_w,reset_e_r);
fifo_rst_mon1.my_if6 = my_if1;
fifo_chk_rst1.my_if7 = my_if1;
fork
fifo_rst_mon1.run();
fifo_chk_rst1.run();
join
end







/*initial
begin
$vcdpluson;
end
*/

initial begin
    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars;
    $fsdbDumpon;
end



asyn_fifo asyn_fifo1(
.wclk,
.rclk,
.wrst_n,
.rrst_n,
.winc(my_if1.winc),
.rinc(my_if1.rinc),
.wdata(my_if1.wdata),
.wfull(my_if1.wfull),
.rempty(my_if1.rempty),
.rdata(my_if1.rdata)
);

endmodule




/*for(int i = 0; i < 200; i++)
begin
@(negedge wclk)
if(!wfull)  
begin
wdata =$urandom;
$display("@%0t: %d number sent",$time,i+1);
end
end
*/
//$dumpfile(".vcd");
//$dumpvars(0,tb_asyn_fifo.asyn_fifo1);
//#10000;
//$stop;

/*reg wclk,rclk,wrst_n,rrst_n,winc,rinc;
reg [7 : 0] wdata;
wire wfull,rempty;
wire [7 : 0] rdata;
*/
/*initial begin
    my_driver drv;
    drv = new("drv",null);
    drv.main_phase(null);
       
end
*/
