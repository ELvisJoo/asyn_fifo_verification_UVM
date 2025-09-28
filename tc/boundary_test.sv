`ifndef BOUNDARY_TEST_SV
`define BOUNDARY_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/base_test.sv"
`include "./vip/my_sequence.sv"

// 边界测试用例:验证FIFO深度边界和数据宽度边界
class boundary_test extends base_test;
    `uvm_component_utils(boundary_test)
    
    // FIFO深度(在run_phase中从接口获取)
    int unsigned fifo_depth;
    // 数据宽度(根据实际事务类型调整,这里假设8位)
    parameter DATA_WIDTH = 8;
    
    function new(string name = "boundary_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 确保sequencer获取接口
        if (env.i_agent.wseqr != null) begin
            env.i_agent.wseqr.vif = vif;
        end
        if (env.o_agent.rseqr != null) begin
            env.o_agent.rseqr.vif = vif;
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        write_sequence wseq;
        read_sequence  rseq;
        my_transaction single_tr;
        
        phase.raise_objection(this, "启动边界测试");
        `uvm_info("BOUNDARY_TEST", "===== 开始边界测试 =====", UVM_MEDIUM)
        
        // 等待复位完成
        wait(vif.wrst_n && vif.rrst_n);
        repeat(5) @(posedge vif.wclk);
        `uvm_info("BOUNDARY_TEST", "DUT复位完成,开始测试流程", UVM_MEDIUM)
        
        // 获取FIFO深度(2^ADDRSIZEL)
        fifo_depth = 1 << vif.ADDRSIZEL;
        `uvm_info("BOUNDARY_TEST", $sformatf("检测到FIFO深度: %0d, 数据宽度: %0d位", 
                  fifo_depth, DATA_WIDTH), UVM_MEDIUM)
        
        // -------------------------- 1. 深度边界测试 --------------------------
        `uvm_info("BOUNDARY_TEST", "===== 开始深度边界测试 =====", UVM_MEDIUM)
        
        // 1.1 写入FIFO深度-1个数据,验证未满(full=0)
        `uvm_info("BOUNDARY_TEST", $sformatf("步骤1: 写入 %0d 个数据(深度-1)", fifo_depth-1), UVM_MEDIUM)
        wseq = write_sequence::type_id::create("wseq_depth_1");
        if (!wseq.randomize() with {
            write_count == fifo_depth - 1;
            delay == 1;
        }) begin
            `uvm_fatal("BOUNDARY_TEST", "写序列1随机化失败!")
        end
        wseq.start(env.i_agent.wseqr);
        
        // 验证未满状态
        @(posedge vif.wclk);
        if (vif.wfull !== 1'b0) begin
            `uvm_error("BOUNDARY_ERR", $sformatf("深度-1验证失败: 预期full=0, 实际full=%b", vif.wfull))
        end else begin
            `uvm_info("BOUNDARY_PASS", "深度-1验证通过: full=0", UVM_MEDIUM)
        end
        
        // 1.2 再写入1个数据(总深度个数),验证已满(full=1)
        `uvm_info("BOUNDARY_TEST", $sformatf("步骤2: 再写入1个数据(共 %0d 个,达到深度)", fifo_depth), UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("single_tr1");
        start_item(single_tr);
        assert(single_tr.randomize() with {winc == 1'b1; rinc == 1'b0;});
        finish_item(single_tr);
        @(posedge vif.wclk);
        
        // 验证满状态
        if (vif.wfull !== 1'b1) begin
            `uvm_error("BOUNDARY_ERR", $sformatf("深度验证失败: 预期full=1, 实际full=%b", vif.wfull))
        end else begin
            `uvm_info("BOUNDARY_PASS", "深度验证通过: full=1", UVM_MEDIUM)
        end
        
        // 1.3 从满状态读出1个数据,验证非满非空(full=0且empty=0)
        `uvm_info("BOUNDARY_TEST", "步骤3: 从满状态读出1个数据", UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("single_tr2");
        start_item(single_tr);
        assert(single_tr.randomize() with {winc == 1'b0; rinc == 1'b1;});
        finish_item(single_tr);
        @(posedge vif.rclk);
        
        // 验证非满非空
        if (vif.wfull !== 1'b0 || vif.rempty !== 1'b0) begin
            `uvm_error("BOUNDARY_ERR", $sformatf("满状态读出验证失败: 预期full=0且empty=0, 实际full=%b, empty=%b", 
                      vif.wfull, vif.rempty))
        end else begin
            `uvm_info("BOUNDARY_PASS", "满状态读出验证通过: full=0且empty=0", UVM_MEDIUM)
        end
        
        // 1.4 读出剩余所有数据至空状态
        `uvm_info("BOUNDARY_TEST", "步骤4: 读出剩余数据至空状态", UVM_MEDIUM)
        rseq = read_sequence::type_id::create("rseq_empty");
        if (!rseq.randomize() with {
            read_count == fifo_depth - 1;  // 剩余fifo_depth-1个数据
            delay == 1;
        }) begin
            `uvm_fatal("BOUNDARY_TEST", "读序列1随机化失败!")
        end
        rseq.start(env.o_agent.rseqr);
        
        // 验证空状态
        @(posedge vif.rclk);
        if (vif.rempty !== 1'b1) begin
            `uvm_error("BOUNDARY_ERR", $sformatf("空状态验证失败: 预期empty=1, 实际empty=%b", vif.rempty))
        end else begin
            `uvm_info("BOUNDARY_PASS", "空状态验证通过: empty=1", UVM_MEDIUM)
        end
        
        // 1.5 从空状态写入1个数据,验证非空(empty=0且full=0)
        `uvm_info("BOUNDARY_TEST", "步骤5: 从空状态写入1个数据", UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("single_tr3");
        start_item(single_tr);
        assert(single_tr.randomize() with {
            winc == 1'b1; 
            rinc == 1'b0;
            wdata == 8'h55;  // 特殊标记值
        });
        finish_item(single_tr);
        @(posedge vif.wclk);
        
        // 验证非空非满
        if (vif.rempty !== 1'b0 || vif.wfull !== 1'b0) begin
            `uvm_error("BOUNDARY_ERR", $sformatf("空状态写入验证失败: 预期empty=0且full=0, 实际empty=%b, full=%b", 
                      vif.rempty, vif.wfull))
        end else begin
            `uvm_info("BOUNDARY_PASS", "空状态写入验证通过: empty=0且full=0", UVM_MEDIUM)
        end
        
        // 清空FIFO,为数据宽度测试做准备
        rseq = read_sequence::type_id::create("rseq_clear");
        if (!rseq.randomize() with {read_count == 1; delay == 0;}) begin
            `uvm_fatal("BOUNDARY_TEST", "读序列2随机化失败!")
        end
        rseq.start(env.o_agent.rseqr);
        `uvm_info("BOUNDARY_TEST", "===== 深度边界测试完成 =====", UVM_MEDIUM)
        
        // -------------------------- 2. 数据宽度边界测试 --------------------------
        `uvm_info("BOUNDARY_TEST", "===== 开始数据宽度边界测试 =====", UVM_MEDIUM)
        
        // 2.1 写入最小数据(8'h00)并验证
        `uvm_info("BOUNDARY_TEST", "步骤1: 写入最小数据(8'h00)", UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("tr_min");
        start_item(single_tr);
        assert(single_tr.randomize() with {
            winc == 1'b1; 
            rinc == 1'b0;
            wdata == 8'h00;  // 最小数据
        });
        finish_item(single_tr);
        // 读取并验证(由scoreboard自动比对,这里打印日志辅助调试)
        rseq = read_sequence::type_id::create("rseq_min");
        if (!rseq.randomize() with {read_count == 1; delay == 1;}) begin
            `uvm_fatal("BOUNDARY_TEST", "读序列3随机化失败!")
        end
        rseq.start(env.o_agent.rseqr);
        
        // 2.2 写入最大数据(8'hFF)并验证
        `uvm_info("BOUNDARY_TEST", "步骤2: 写入最大数据(8'hFF)", UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("tr_max");
        start_item(single_tr);
        assert(single_tr.randomize() with {
            winc == 1'b1; 
            rinc == 1'b0;
            wdata == 8'hFF;  // 最大数据
        });
        finish_item(single_tr);
        // 读取并验证
        rseq = read_sequence::type_id::create("rseq_max");
        if (!rseq.randomize() with {read_count == 1; delay == 1;}) begin
            `uvm_fatal("BOUNDARY_TEST", "读序列4随机化失败!")
        end
        rseq.start(env.o_agent.rseqr);
        
        // 2.3 写入特殊值(8'hAA)并验证
        `uvm_info("BOUNDARY_TEST", "步骤3: 写入特殊值(8'hAA)", UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("tr_aa");
        start_item(single_tr);
        assert(single_tr.randomize() with {
            winc == 1'b1; 
            rinc == 1'b0;
            wdata == 8'hAA;  // 特殊值1
        });
        finish_item(single_tr);
        // 读取并验证
        rseq = read_sequence::type_id::create("rseq_aa");
        if (!rseq.randomize() with {read_count == 1; delay == 1;}) begin
            `uvm_fatal("BOUNDARY_TEST", "读序列5随机化失败!")
        end
        rseq.start(env.o_agent.rseqr);
        
        // 2.4 写入特殊值(8'h55)并验证
        `uvm_info("BOUNDARY_TEST", "步骤4: 写入特殊值(8'h55)", UVM_MEDIUM)
        single_tr = my_transaction::type_id::create("tr_55");
        start_item(single_tr);
        assert(single_tr.randomize() with {
            winc == 1'b1; 
            rinc == 1'b0;
            wdata == 8'h55;  // 特殊值2
        });
        finish_item(single_tr);
        // 读取并验证
        rseq = read_sequence::type_id::create("rseq_55");
        if (!rseq.randomize() with {read_count == 1; delay == 1;}) begin
            `uvm_fatal("BOUNDARY_TEST", "读序列6随机化失败!")
        end
        rseq.start(env.o_agent.rseqr);
        
        `uvm_info("BOUNDARY_TEST", "===== 数据宽度边界测试完成 =====", UVM_MEDIUM)
        
        // 测试完成等待
        repeat(10) @(posedge vif.wclk);
        `uvm_info("BOUNDARY_TEST", "===== 所有边界测试完成 =====", UVM_MEDIUM)
        
        phase.drop_objection(this, "边界测试结束");
    endtask
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("BOUNDARY_SUMMARY", "=====================================", UVM_LOW)
        `uvm_info("BOUNDARY_SUMMARY", "边界测试结果汇总:", UVM_LOW)
        `uvm_info("BOUNDARY_SUMMARY", $sformatf("1. FIFO深度: %0d 验证完成", fifo_depth), UVM_LOW)
        `uvm_info("BOUNDARY_SUMMARY", $sformatf("2. 数据宽度: %0d位 验证完成", DATA_WIDTH), UVM_LOW)
        `uvm_info("BOUNDARY_SUMMARY", "查看UVM_ERROR确认是否有边界异常", UVM_LOW)
        `uvm_info("BOUNDARY_SUMMARY", "=====================================", UVM_LOW)
    endfunction
endclass

`endif

//边界测试用例说明
//该testcase实现了基础的边界测试功能,主要包含两部分核心测试内容:

//1. 深度边界测试
//写入深度 - 1 个数据:      验证 FIFO 未满(full=0)
//写入深度个数据:           验证 FIFO 已满(full=1)
//从满状态读出 1 个数据:    验证 FIFO 处于非满非空状态(full=0 且 empty=0)
//从空状态写入 1 个数据:    验证 FIFO 处于非空非满状态(empty=0 且 full=0)

//2. 数据宽度边界测试
//最小数据测试:         写入 8'h00 并验证读出值一致
//最大数据测试:         写入 8'hFF 并验证读出值一致
//特殊值测试:           分别写入 8'hAA 和 8'h55 验证数据完整性

//实现特点:
//采用单事务写入 + 读取的方式,确保数据一对一验证
//依赖scoreboard(my_scoreboard)自动比对读写数据
//每个数据点都有清晰的日志记录,便于调试

//使用说明
//确保 my_transaction 中包含 wdata 字段(8 位宽)
//确保接口(my_if)中定义了 ADDRSIZEL 参数(用于计算 FIFO 深度)

//测试结果会在 report_phase 汇总,通过检查日志中的 UVM_ERROR 确认是否存在边界问题
//该测试用例与已有序列(write_sequence/read_sequence)和基础测试(base_test)完全兼容,可直接加入验证环境运行。
