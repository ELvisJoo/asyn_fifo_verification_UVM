`ifndef MY_DRIVER_SV
`define MY_DRIVER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_transaction.sv"
`include "./vip/my_if.sv"

// 写驱动:负责写时钟域的激励驱动
class w_driver extends uvm_driver #(my_transaction);
    virtual my_if.WDRIVER vif;  // 虚拟接口,写驱动视角
    
    `uvm_component_utils(w_driver)
    
    function new(string name = "w_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从配置数据库获取接口
        if(!uvm_config_db#(virtual my_if.WDRIVER)::get(this, "", "w_if", vif)) begin
            `uvm_fatal("W_DRIVER", "无法获取写接口w_if")
        end
    endfunction
    
    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        phase.raise_objection(this);
        // 复位期间初始化信号
        vif.wdrv_cb.wdata <= '0;
        vif.wdrv_cb.winc  <= 1'b0;
        @(posedge vif.wrst_n);  // 等待复位释放
        phase.drop_objection(this);
    endtask
    
    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        forever begin
            my_transaction tr;
            // 从sequencer获取事务
            seq_item_port.get_next_item(tr);
            
            // 驱动信号到接口
            @(vif.wdrv_cb);
            // 当FIFO未满时才驱动有效写操作
            if(!vif.wdrv_cb.wfull) begin
                vif.wdrv_cb.wdata <= tr.wdata;
                vif.wdrv_cb.winc  <= tr.winc;
                `uvm_info("W_DRIVER", $sformatf("驱动写操作: %s", tr.convert2string()), UVM_HIGH)
            end
            else begin
                // FIFO已满时,不驱动写使能
                vif.wdrv_cb.winc  <= 1'b0;
                `uvm_warning("W_DRIVER", "FIFO已满,禁止写操作")
            end
            
            // 通知sequencer事务已完成
            seq_item_port.item_done();
        end
    endtask
endclass

// 读驱动:负责读时钟域的激励驱动
class r_driver extends uvm_driver #(my_transaction);
    virtual my_if.RDRIVER vif;  // 虚拟接口,读驱动视角
    
    `uvm_component_utils(r_driver)
    
    function new(string name = "r_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从配置数据库获取接口
        if(!uvm_config_db#(virtual my_if.RDRIVER)::get(this, "", "r_if", vif)) begin
            `uvm_fatal("R_DRIVER", "无法获取读接口r_if")
        end
    endfunction
    
    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        phase.raise_objection(this);
        // 复位期间初始化信号
        vif.rdrv_cb.rinc  <= 1'b0;
        @(posedge vif.rrst_n);  // 等待复位释放
        phase.drop_objection(this);
    endtask
    
    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        forever begin
            my_transaction tr;
            // 从sequencer获取事务
            seq_item_port.get_next_item(tr);
            
            // 驱动信号到接口
            @(vif.rdrv_cb);
            // 当FIFO非空时才驱动有效读操作
            if(!vif.rdrv_cb.rempty) begin
                vif.rdrv_cb.rinc  <= tr.rinc;
                `uvm_info("R_DRIVER", $sformatf("驱动读操作: %s", tr.convert2string()), UVM_HIGH)
            end
            else begin
                // FIFO为空时,不驱动读使能
                vif.rdrv_cb.rinc  <= 1'b0;
                `uvm_warning("R_DRIVER", "FIFO为空,禁止读操作")
            end
            
            // 通知sequencer事务已完成
            seq_item_port.item_done();
        end
    endtask
endclass

`endif

// 针对异步 FIFO 的跨时钟域特性,这里采用了分离的写驱动 (w_driver) 和读驱动 (r_driver) 设计:
// 1. 驱动分离:
// 写驱动 (w_driver):在写时钟域 (wclk) 下工作,负责驱动wdata和winc信号
// 读驱动 (r_driver):在读时钟域 (rclk) 下工作,负责驱动rinc信号
// 2. 接口处理:
// 分别使用my_if.WDRIVER和my_if.RDRIVER modport,确保访问权限正确
// 通过 UVM 配置数据库获取虚拟接口,实现环境的灵活性
// 3. 复位处理:
// 在复位阶段初始化驱动信号,确保复位期间信号状态正确
// 等待复位释放后才开始正常驱动
// 4. 驱动控制:
// 写驱动会检查wfull信号,FIFO 满时自动禁止写操作
// 读驱动会检查rempty信号,FIFO 空时自动禁止读操作
// 避免产生无效激励,提高验证效率
// 5. 事务处理:
// 通过seq_item_port从 sequencer 获取事务
// 完成驱动后通过item_done()通知 sequencer