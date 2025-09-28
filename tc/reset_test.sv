`ifndef RESET_TEST_SV
`define RESET_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/base_test.sv"
`include "./vip/my_sequence.sv"

// 复位测试:验证FIFO在复位情况下的行为
class reset_test extends base_test;
    `uvm_component_utils(reset_test)
    
    function new(string name = "reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        write_sequence wseq;  // 写序列
        read_sequence rseq;   // 读序列
        
        phase.raise_objection(this);
        
        `uvm_info("RESET_TEST", "开始复位测试...", UVM_MEDIUM)
        
        // 等待初始复位完成
        wait(vif.wrst_n && vif.rrst_n);
        #100;  // 等待稳定
        
        // 1. 写入一些数据
        `uvm_info("RESET_TEST", "复位前写入一些数据...", UVM_MEDIUM)
        wseq = write_sequence::type_id::create("wseq");
        wseq.data_count = 8;  // 写入8个数据
        wseq.start(env.i_agent.wseqr);
        
        // 2. 单独写复位测试
        `uvm_info("RESET_TEST", "执行写复位...", UVM_MEDIUM)
        @(posedge vif.wclk);
        vif.wrst_n = 1'b0;  // 拉低写复位
        repeat(5) @(posedge vif.wclk);
        vif.wrst_n = 1'b1;  // 释放写复位
        #100;
        
        // 3. 单独读复位测试
        `uvm_info("RESET_TEST", "执行读复位...", UVM_MEDIUM)
        @(posedge vif.rclk);
        vif.rrst_n = 1'b0;  // 拉低读复位
        repeat(5) @(posedge vif.rclk);
        vif.rrst_n = 1'b1;  // 释放读复位
        #100;
        
        // 4. 同时读写复位测试
        `uvm_info("RESET_TEST", "同时执行读写复位...", UVM_MEDIUM)
        @(posedge vif.wclk);
        vif.wrst_n = 1'b0;
        vif.rrst_n = 1'b0;
        repeat(5) @(posedge vif.wclk);
        vif.wrst_n = 1'b1;
        vif.rrst_n = 1'b1;
        #100;
        
        // 5. 复位后验证FIFO状态
        `uvm_info("RESET_TEST", "复位后验证FIFO状态...", UVM_MEDIUM)
        rseq = read_sequence::type_id::create("rseq");
        rseq.max_count = 5;  // 尝试读取(应为空)
        rseq.start(env.o_agent.rseqr);
        
        // 测试完成后等待
        repeat(20) @(posedge vif.wclk);
        
        phase.drop_objection(this);
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("RESET_TEST", "复位测试完成", UVM_MEDIUM)
    endfunction
endclass

`endif
// 全面验证复位功能:
// --单独写复位测试
// --单独读复位测试
// --同时读写复位测试
// --复位前后数据状态变化
// 验证复位信号对wfull、rempty标志和内部数据的影响