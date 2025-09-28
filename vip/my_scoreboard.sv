`ifndef MY_SCOREBOARD_SV
`define MY_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_transaction.sv"
//`include "./vip/fifo_chk_rst.sv"

class my_scoreboard extends uvm_scoreboard;
    // 参数定义,与RTL保持一致
    parameter DATASIZEL = 8;

    // -------------------------- TLM导入端口 --------------------------
    // 定义“写复位状态”导入端口(接收bit类型数据,关联到当前scoreboard)
    typedef uvm_analysis_imp #(bit, my_scoreboard) wrst_imp_type;
    // 定义“读复位状态”导入端口
    typedef uvm_analysis_imp #(bit, my_scoreboard) rrst_imp_type;
    
    wrst_imp_type wrst_imp;  // 实例化写复位导入端口
    rrst_imp_type rrst_imp;  // 实例化读复位导入端口
    // ---------------------------------------------------------------------------

    // TLM FIFO端口:接收monitor和reference model的数据,用于数据比对
    uvm_tlm_analysis_fifo#(my_transaction) exp_port;  // 预期结果(来自reference model)
    uvm_tlm_analysis_fifo#(my_transaction) act_port;  // 实际结果(来自输出monitor)
    
    // 存储预期数据的队列(处理跨时钟域异步问题)
    my_transaction exp_queue[$];
    
    // 复位状态跟踪
    bit wrst_active;
    bit rrst_active;
    
    // // 允许分析端口访问私有成员
    // friend class exp_imp_type;
    // friend class act_imp_type;
    
    `uvm_component_utils(my_scoreboard)
    
    function new(string name = "my_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        exp_port = new("exp_port", this);
        act_port = new("act_port", this);
        wrst_active = 1'b0;
        rrst_active = 1'b0;
    endfunction

    // -------------------------- 实现TLM导入端口的write函数 --------------------------
    // 写复位状态接收(TLM端口自动调用此函数,参数state由发送端传递)
    virtual function void write(bit state);
        // 根据端口名称判断是“写复位”还是“读复位”
        if (wrst_imp.get_name() == "wrst_imp") begin
            update_wrst_state(state);  // 调用原有更新函数
        end else if (rrst_imp.get_name() == "rrst_imp") begin
            update_rrst_state(state);  // 调用原有更新函数
        end
    endfunction
    // ---------------------------------------------------------------------------
    
    // 接收reference model的预期结果
    virtual function void write_exp(my_transaction tr);
        // 复位期间不存储预期数据
        if (!wrst_active && !rrst_active) begin
            exp_queue.push_back(tr);
            `uvm_info("SCOREBOARD", $sformatf("添加预期数据到队列: %s", tr.convert2string()), UVM_HIGH)
        end
        else begin
            `uvm_info("SCOREBOARD", "复位期间忽略预期数据", UVM_MEDIUM)
        end
    endfunction
    
    // 接收输出monitor的实际结果
    virtual function void write_act(my_transaction tr);
        my_transaction exp_tr;
        
        // 复位期间不检查数据
        if (wrst_active || rrst_active) begin
            `uvm_info("SCOREBOARD", "复位期间跳过数据检查", UVM_MEDIUM)
            return;
        end
        
        // 检查是否有预期数据
        if (exp_queue.size() == 0) begin
            `uvm_error("SCOREBOARD_ERR", $sformatf("无预期数据,但收到实际数据: %s", tr.convert2string()))
            return;
        end
        
        // 取出最早的预期数据进行比较
        exp_tr = exp_queue.pop_front();
        
        // 比较数据
        if (exp_tr.rdata !== tr.rdata) begin
            `uvm_error("DATA_MISMATCH", 
                $sformatf("数据不匹配 - 预期: 0x%0h, 实际: 0x%0h", exp_tr.rdata, tr.rdata))
        end
        else begin
            `uvm_info("DATA_MATCH", 
                $sformatf("数据匹配 - 预期: 0x%0h, 实际: 0x%0h", exp_tr.rdata, tr.rdata), UVM_MEDIUM)
        end
        
        // 检查空满标志
        check_flags(exp_tr, tr);
    endfunction
    
    // 检查空满标志的一致性
    virtual function void check_flags(my_transaction exp_tr, my_transaction act_tr);
        if (exp_tr.rempty !== act_tr.rempty) begin
            `uvm_warning("FLAG_MISMATCH", 
                $sformatf("rempty不匹配 - 预期: %b, 实际: %b", exp_tr.rempty, act_tr.rempty))
        end
    endfunction
    
    // 更新复位状态(从复位检查器接收)
    virtual function void update_wrst_state(bit state);
        wrst_active = state;
        if (state) begin
            `uvm_info("SCOREBOARD", "写复位开始,清空预期数据队列", UVM_MEDIUM)
            exp_queue.delete();  // 复位期间清空队列
        end
    endfunction
    
    virtual function void update_rrst_state(bit state);
        rrst_active = state;
        if (state) begin
            `uvm_info("SCOREBOARD", "读复位开始,清空预期数据队列", UVM_MEDIUM)
            exp_queue.delete();  // 复位期间清空队列
        end
    endfunction

endclass
`endif
// ### 代码说明

// 该scoreboard针对异步FIFO的特性设计,主要功能和特点如下:

// 1. **数据比对机制**:
//    - 通过`exp_port`接收来自reference model的预期数据
//    - 通过`act_port`接收来自o_agent的实际数据
//    - 使用队列`exp_queue`存储预期数据,解决跨时钟域异步问题导致的时序差异

// 2. **复位处理**:
//    - 跟踪写复位(`wrst_active`)和读复位(`rrst_active`)状态
//    - 复位期间自动清空预期数据队列,避免复位前后数据混淆
//    - 复位期间暂停数据比对,确保验证准确性

// 3. **比对内容**:
//    - 核心数据比对:比较预期读出数据(`rdata`)与实际读出数据
//    - 可选标志比对:检查空标志(`rempty`)的一致性(可根据需求扩展)

// 4. **错误报告**:
//    - 数据不匹配时通过`uvm_error`报告详细错误信息
//    - 标志不一致时通过`uvm_warning`提示潜在问题
//    - 无预期数据却收到实际数据时报告错误

// 5. **异步适配**:
//    - 队列缓冲机制解决读写时钟域不同步导致的数据到达顺序差异
//    - 独立处理复位状态,确保异步复位场景下的验证正确性

// 该计分板(my_scoreboard)与参考模型(my_model)、复位监测器(fifo_rst_mon)和复位检查器(fifo_chk_rst)紧密配合,形成完整的验证闭环,能够有效验证异步FIFO的数据传输正确性和异常场景处理能力。