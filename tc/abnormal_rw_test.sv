`ifndef ABNORMAL_RW_TEST_SV
`define ABNORMAL_RW_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/base_test.sv"
`include "./vip/my_sequence.sv"

// 异常读写测试:验证FIFO在同时读写情况下的行为
class abnormal_rw_test extends base_test;
    `uvm_component_utils(abnormal_rw_test)
    
    function new(string name = "abnormal_rw_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        write_sequence wseq;  // 写序列
        read_sequence rseq;   // 读序列
        
        phase.raise_objection(this);
        
        `uvm_info("ABNORMAL_RW_TEST", "开始异常读写测试...", UVM_MEDIUM)
        
        // 等待复位完成
        wait(vif.wrst_n && vif.rrst_n);
        #100;  // 等待稳定
        
        // 1. 先写入部分数据
        wseq = write_sequence::type_id::create("wseq");
        wseq.data_count = 5;  // 写入5个数据
        wseq.start(env.i_agent.wseqr);
        
        // 2. 同时进行大量读写操作
        `uvm_info("ABNORMAL_RW_TEST", "开始同时进行大量读写操作...", UVM_MEDIUM)
        wseq.data_count = 50;  // 连续写入50个数据
        rseq = read_sequence::type_id::create("rseq");
        rseq.max_count = 50;   // 连续读取50次
        
        fork
            wseq.start(env.i_agent.wseqr);
            rseq.start(env.o_agent.rseqr);
        join
        
        // 3. 测试边界情况:FIFO接近空和满时的同时读写
        `uvm_info("ABNORMAL_RW_TEST", "测试边界情况下的同时读写...", UVM_MEDIUM)
        repeat(3) begin
            // 写入数据至接近满
            wseq.data_count = 10;
            wseq.start(env.i_agent.wseqr);
            
            // 同时读写
            fork
                begin
                    wseq.data_count = 5;
                    wseq.start(env.i_agent.wseqr);
                end
                begin
                    rseq.max_count = 5;
                    rseq.start(env.o_agent.rseqr);
                end
            join
        end
        
        // 测试完成后等待
        repeat(20) @(posedge vif.wclk);
        
        phase.drop_objection(this);
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ABNORMAL_RW_TEST", "异常读写测试完成", UVM_MEDIUM)
    endfunction
endclass

`endif

// 测试同时读写的边界场景:
// --大量数据同时读写
// --FIFO 接近空时的同时读写
// --FIFO 接近满时的同时读写
// 验证异步 FIFO 在高负载交叉操作下的数据一致性