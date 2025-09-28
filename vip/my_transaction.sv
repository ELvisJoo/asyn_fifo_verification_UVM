`ifndef MY_TRANSACTION_SV
`define MY_TRANSACTION_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class my_transaction extends uvm_sequence_item;
    // 数据位宽/地址位宽,与RTL保持一致
    parameter DATASIZEL = 8;
    parameter ADDRSIZEL = 4;

    // 写操作相关信号
    rand bit [DATASIZEL-1:0] wdata;  // 写入数据
    rand bit                 winc;   // 写使能
    
    // 读操作相关信号
    rand bit                 rinc;   // 读使能
    
    // 输出信号(监测用,非随机)
    bit [DATASIZEL-1:0]     rdata;  // 读出数据
    bit                     wfull;  // 写满标志
    bit                     rempty; // 读空标志
    
    // 基本的操作约束
    constraint c_fifo_op {
        // 防止在同一周期同时产生读写请求,可根据实际需求调整
        (winc && rinc) -> 0;

        // 读写操作概率控制,可根据测试需求调整
        // 基础测试(均匀读写)
        winc dist {1'b1 := 1, 1'b0 := 1};   // 写请求概率 ~50%
        rinc dist {1'b1 := 1, 1'b0 := 1};   // 读请求概率 ~50%
        // 正常测试（空满均衡）
        //winc dist {1'b1 := 2, 1'b0 := 1};  // 写请求概率 ~66%（更易触发满状态）
        //rinc dist {1'b1 := 2, 1'b0 := 1};  // 读请求概率 ~66%（更易触发空状态）
        // 压力测试（写密集）
        // winc dist {1'b1 := 5, 1'b0 := 1};  // 写请求概率 ~83%(快速写满FIFO)
        // rinc dist {1'b1 := 1, 1'b0 := 2};  // 读请求概率 ~33%
    }
    
    // UVM工厂注册
    `uvm_object_utils_begin(my_transaction)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(winc,  UVM_ALL_ON)
        `uvm_field_int(rinc,  UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
        `uvm_field_int(wfull, UVM_ALL_ON)
        `uvm_field_int(rempty, UVM_ALL_ON)
    `uvm_object_utils_end
    
    // 构造函数
    function new(string name = "my_transaction");
        super.new(name);
    endfunction
    
    // 自定义打印函数
    virtual function string convert2string();
        return $sformatf("wdata=0x%0h, winc=%b, rinc=%b, rdata=0x%0h, wfull=%b, rempty=%b",
                         wdata, winc, rinc, rdata, wfull, rempty);
    endfunction
    
    // 比较函数,用于验证数据一致性
    virtual function bit compare(my_transaction tr, uvm_comparer comparer);
        bit status = 1'b1;
        
        // 比较读出的数据(输入数据与输出数据的比较可能需要在scoreboard中考虑时序)
        if (this.rdata !== tr.rdata) begin
            status = 1'b0;
            `uvm_error("COMPARE_ERR", $sformatf("rdata不匹配: 预期=0x%0h, 实际=0x%0h", this.rdata, tr.rdata))
        end
        
        return status;
    endfunction

endclass

`endif

// 1. 参数定义:包含了与 RTL 一致的DATASIZEL参数,确保数据位宽匹配

// 2. 信号定义:
//  ---写入相关:wdata(写入数据)和winc(写使能)
//  ---读出相关:rinc(读使能)和rdata(读出数据)
//  ---状态信号:wfull(写满标志)和rempty(读空标志)

// 3. 约束条件:
//  ---基本操作约束:c_fifo_op
//  ---确保在同一周期内不会同时产生读写请求
//  ---读写操作的概率分布,可根据测试需求调整

// 4. 功能函数:
// convert2string:格式化打印 transaction 内容,便于调试
// compare:比较两个 transaction 的关键字段,主要用于验证读出数据的正确性
