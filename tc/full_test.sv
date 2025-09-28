`ifndef FULL_TEST_SV
`define FULL_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/base_test.sv"
`include "./vip/my_sequence.sv"

// 满状态测试:验证FIFO在满状态下的写操作行为
class full_test extends base_test;
    // FIFO深度 = 2^ADDRSIZEL
    parameter ADDRSIZEL = 4;// 地址位宽参数,与RTL保持一致
    localparam DEPTH = 1 << ADDRSIZEL;
    
    `uvm_component_utils(full_test)
    
    function new(string name = "full_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        write_sequence wseq;  // 写序列
        read_sequence rseq;   // 读序列
        
        phase.raise_objection(this);
        
        `uvm_info("FULL_TEST", $sformatf("开始满状态测试,FIFO深度: %0d", DEPTH), UVM_MEDIUM)
        
        // 等待复位完成
        wait(vif.wrst_n && vif.rrst_n);
        #100;  // 等待稳定
        
        // 1. 写满FIFO
        wseq = write_sequence::type_id::create("wseq");
        wseq.data_count = DEPTH + 5;  // 写入数据量超过FIFO深度
        wseq.start(env.i_agent.wseqr);
        
        // 2. 满状态下继续写操作(验证wfull标志是否有效)
        `uvm_info("FULL_TEST", "满状态下继续写入操作...", UVM_MEDIUM)
        repeat(5) begin
            @(posedge vif.wclk);
            if (vif.wfull) begin
                `uvm_info("FULL_TEST", "检测到wfull有效,验证满状态保护机制", UVM_HIGH)
            end
        end
        
        // 3. 读出部分数据后再写入
        `uvm_info("FULL_TEST", "读出部分数据后再写入...", UVM_MEDIUM)
        rseq = read_sequence::type_id::create("rseq");
        rseq.max_count = 10;  // 读出10个数据
        rseq.start(env.o_agent.rseqr);
        
        // 再次写入数据直到满
        wseq.data_count = 15;
        wseq.start(env.i_agent.wseqr);
        
        // 测试完成后等待
        repeat(20) @(posedge vif.wclk);
        
        phase.drop_objection(this);
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("FULL_TEST", "满状态测试完成", UVM_MEDIUM)
    endfunction
endclass

`endif
// 验证 FIFO 满状态特性:
// --写满 FIFO 的过程验证
// --满状态下写操作的保护机制
// --部分数据读出后再次写满的行为
// 验证wfull标志的有效性和满状态下的写保护