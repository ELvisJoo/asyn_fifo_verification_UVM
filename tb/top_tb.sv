`timescale 1ns / 1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

`include "./vip/my_if.sv          "  
`include "./vip/my_transaction.sv "   
`include "./vip/my_sequencer.sv   "
`include "./vip/my_sequence.sv    "
`include "./vip/my_driver.sv      "
`include "./vip/in_monitor.sv     "  
`include "./vip/out_monitor.sv    "  
`include "./vip/i_agt.sv          "
`include "./vip/o_agt.sv          " 
`include "./vip/my_model.sv       "    
`include "./vip/my_scoreboard.sv  "
`include "./vip/fifo_rst_mon.sv   "  
`include "./vip/fifo_chk_rst.sv   " 
`include "./vip/base_test.sv      "
`include "./vip/my_env.sv         "

module top_tb;
    // 参数定义,与DUT保持一致
    parameter ADDRSIZEL = 4;
    parameter DATASIZEL = 8;
    
    // 时钟和复位信号
    reg wclk;
    reg rclk;
    reg wrst_n;
    reg rrst_n;
    
    // 实例化接口
    my_if #(.ADDRSIZEL(ADDRSIZEL), .DATASIZEL(DATASIZEL)) 
        fifo_if (.wclk(wclk), .wrst_n(wrst_n), .rclk(rclk), .rrst_n(rrst_n));
    
    // 实例化DUT(异步FIFO)
    asyn_fifo #(.ADDRSIZEL(ADDRSIZEL), .DATASIZEL(DATASIZEL)) 
        dut (
            .wclk      (wclk),
            .wrst_n    (wrst_n),
            .winc      (fifo_if.winc),
            .wdata     (fifo_if.wdata),
            .wfull     (fifo_if.wfull),
            
            .rclk      (rclk),
            .rrst_n    (rrst_n),
            .rinc      (fifo_if.rinc),
            .rdata     (fifo_if.rdata),
            .rempty    (fifo_if.rempty)
        );
    
    // 生成写时钟(100MHz)
    initial begin
        wclk = 1'b0;
        forever #5 wclk = ~wclk;  // 周期10ns
    end
    
    // 生成读时钟(50MHz,与写时钟异步)
    initial begin
        rclk = 1'b0;
        forever #10 rclk = ~rclk;  // 周期20ns
    end
    
    // 生成复位信号
    initial begin
        // 初始复位
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        
        // 释放复位(可错开释放时间,模拟异步复位)
        #100;
        wrst_n = 1'b1;
        #50;  // 写复位先释放,读复位后释放
        rrst_n = 1'b1;
    end
    
    // UVM测试启动
    initial begin
        // 将接口注册到UVM配置数据库
        uvm_config_db#(virtual my_if)::set(null, "uvm_test_top", "my_if", fifo_if);
        
        // 启动UVM测试
        run_test();
    end
    
    // 波形dump(用于Verdi查看)
    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars(0, top_tb);  // dump整个测试平台的信号
        $fsdbDumpSVA(0, top_tb);   // dump断言信息
    end

endmodule
