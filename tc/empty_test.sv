`ifndef EMPTY_TEST_SV
`define EMPTY_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/base_test.sv"
`include "./vip/my_sequence.sv"

// 空状态测试:验证FIFO在空状态下的读操作行为
class empty_test extends base_test;
    `uvm_component_utils(empty_test)
    
    function new(string name = "empty_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        // 1. 声明一次变量:读写序列
        read_sequence rseq;  // 读序列
        write_sequence wseq; // 写序列  
        phase.raise_objection(this);
        
        `uvm_info("EMPTY_TEST", "开始空状态测试...", UVM_MEDIUM)
        
        // 2. 等待复位完成(复位后FIFO为空,用时钟边沿比用计时器(比如#100)更精准)
        wait(vif.wrst_n && vif.rrst_n);
        repeat(5) @(posedge vif.rclk);  // 等待5个读时钟周期稳定
        `uvm_info("EMPTY_TEST", "DUT复位完成,FIFO初始为空", UVM_MEDIUM) 
        
        // 3. 创建并启动读序列(在空状态下进行读操作: 创建-------→随机化-------→启动)
        rseq = read_sequence::type_id::create("rseq");
        rseq.max_count = 10;  // 连续10次读操作
        rseq.start(env.o_agent.rseqr);
        
        // 4. 写入少量数据后再次读空
        `uvm_info("EMPTY_TEST", "写入少量数据后再次读空...", UVM_MEDIUM)
        wseq = write_sequence::type_id::create("wseq");

        // wseq.data_count = 3;  // 写入3个数据
        if (!wseq.randomize() with {
            write_count == 3;  // 写入3个数据(匹配序列中的变量名)
            delay == 1;
        }) begin
            `uvm_error("EMPTY_TEST", "写序列随机化失败!")
        end
        if (env.i_agent.wseqr == null) begin
            `uvm_fatal("EMPTY_TEST", "写端 sequencer (wseqr) 未创建!")
        end

        wseq.start(env.i_agent.wseqr);

        
        // 5. 读空FIFO(复用 rseq,重新随机化)
        rseq.max_count = 5;  // 读5次(前3次有效,后2次空读)
        rseq.start(env.o_agent.rseqr);
        
        // 测试完成后等待
        repeat(20) @(posedge vif.wclk);
        
        phase.drop_objection(this);
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("EMPTY_TEST", "空状态测试完成", UVM_MEDIUM)
    endfunction
endclass

`endif
// 专注验证 FIFO 空状态特性:
// --复位后空状态验证
// --空状态下读操作行为
// --部分数据读写后的空状态恢复
// 验证rempty标志的有效性和空状态下的数据安全性