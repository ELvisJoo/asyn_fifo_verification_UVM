`ifndef ABNORMAL_TEST_SV
`define ABNORMAL_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/base_test.sv"
`include "./vip/my_sequence.sv"

// 异常操作测试:验证FIFO在异常情况下的行为
class abnormal_test extends base_test;
    `uvm_component_utils(abnormal_test)
    
    function new(string name = "abnormal_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 配置测试环境
        uvm_config_db#(uvm_active_passive_enum)::set(this, "env.i_agent", "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "env.o_agent", "is_active", UVM_ACTIVE);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        abnormal_test_sequence wseq;  // 写异常序列
        read_sequence rseq;      // 读序列
        
        phase.raise_objection(this);
        
        `uvm_info("ABNORMAL_TEST", "开始异常操作测试...", UVM_MEDIUM)
        
        // 等待复位完成
        wait(vif.wrst_n && vif.rrst_n);
        #100;  // 等待稳定
        
        // 创建序列
        wseq = abnormal_test_sequence::type_id::create("wseq");
        rseq = read_sequence::type_id::create("rseq");
        
        // 并行启动写异常序列和读序列
        fork
            wseq.start(env.i_agent.wseqr);  // 发送异常写操作(包括满状态下写)
            rseq.start(env.o_agent.rseqr);  // 正常读操作
        join
        
        // 测试完成后等待
        repeat(20) @(posedge vif.wclk);
        
        phase.drop_objection(this);
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ABNORMAL_TEST", "异常操作测试完成", UVM_MEDIUM)
    endfunction
endclass

`endif
// 验证 FIFO 在异常操作下的行为,包括:
// --满状态下强制写操作
// --空状态下强制读操作
// --随机无效命令组合
// 通过abnormal_seq序列生成异常激励,验证 FIFO 的保护机制