`ifndef FIFO_CHK_RST_SV
`define FIFO_CHK_RST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_if.sv"
`include "./vip/fifo_rst_mon.sv"
`include "./vip/my_transaction.sv"

class fifo_chk_rst extends uvm_component;   

    // TLM分析输入端口实现:接收复位监测器的复位状态的导入端口
    uvm_analysis_imp#(bit, fifo_chk_rst) wrst_imp;
    uvm_analysis_imp#(bit, fifo_chk_rst) rrst_imp;

    // // TLM分析端口:接收复位监测器的复位状态
    // uvm_blocking_get_port#(my_transaction) wrst_imp;  // 写复位状态导入
    // uvm_tlm_analysis_fifo#(my_transaction) rrst_imp;  // 读复位状态导入

    // *关键* 输出分析端口(发送处理后的复位状态给记分板的发送端口)
    uvm_analysis_port#(bit) wrst_ap;
    uvm_analysis_port#(bit) rrst_ap;

    // 虚拟接口:用于检查复位期间的FIFO状态信号
    virtual my_if vif;
    
    // 内部状态变量
    bit wrst_active;  // 写复位Active标志
    bit rrst_active;  // 读复位Active标志
    
    `uvm_component_utils(fifo_chk_rst)
    
    function new(string name = "fifo_chk_rst", uvm_component parent = null);
        super.new(name, parent);
        // -------------------------- 初始化TLM导入端口 --------------------------
        wrst_imp = new("wrst_imp", this);// 初始化写复位导入端口
        rrst_imp = new("rrst_imp", this);// 初始化写复位导入端口
        // ---------------------------------------------------------------------------
        wrst_active = 1'b0;
        rrst_active = 1'b0;
    endfunction

    // 接收复位监测器的数据,并转发给scoreboard
    virtual function void write(bit state);
        if (wrst_imp.get_name() == "wrst_imp") begin
            wrst_active = state;
            wrst_ap.write(state);  // 转发写复位状态
            `uvm_info("RST_CHK", $sformatf("写复位状态更新为: %b", state), UVM_HIGH)
        end else if (rrst_imp.get_name() == "rrst_imp") begin
            rrst_active = state;
            rrst_ap.write(state);  // 转发读复位状态
            `uvm_info("RST_CHK", $sformatf("读复位状态更新为: %b", state), UVM_HIGH)
        end
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从配置数据库获取接口
        if (!uvm_config_db#(virtual my_if)::get(this, "", "my_if", vif)) begin
            `uvm_fatal("RST_CHK", "无法获取接口my_if")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        // 并行检查写复位和读复位期间的FIFO状态
        fork
            check_wrst_behavior();  // 检查写复位期间的行为
            check_rrst_behavior();  // 检查读复位期间的行为
        join
    endtask
    
    // 写复位状态接收函数(来自复位监测器)
    virtual function void write_wrst(bit rst_state);
        wrst_active = rst_state;
        `uvm_info("RST_CHK", $sformatf("写复位状态更新为: %b", rst_state), UVM_HIGH)
    endfunction
    
    // 读复位状态接收函数(来自复位监测器)
    virtual function void write_rrst(bit rst_state);
        rrst_active = rst_state;
        `uvm_info("RST_CHK", $sformatf("读复位状态更新为: %b", rst_state), UVM_HIGH)
    endfunction
    
    // 检查写复位期间的FIFO行为
    virtual task check_wrst_behavior();
        forever begin
            @(negedge vif.wclk);  // 写时钟域检查
            
            if (wrst_active) begin
                // 写复位期间,写满标志应清零
                if (vif.wfull !== 1'b0) begin
                    `uvm_error("RST_CHK_ERR", 
                        $sformatf("写复位期间wfull应为0,实际为%b", vif.wfull))
                end
                
                // 写复位期间,写使能应无效(可选检查,取决于设计需求)
                if (vif.winc === 1'b1) begin
                    `uvm_warning("RST_CHK_WARN", 
                        "写复位期间检测到有效写使能,可能导致非预期行为")
                end
            end
        end
    endtask
    
    // 检查读复位期间的FIFO行为
    virtual task check_rrst_behavior();
        forever begin
            @(negedge vif.rclk);  // 读时钟域检查
            
            if (rrst_active) begin
                // 读复位期间,读空标志应置位
                if (vif.rempty !== 1'b1) begin
                    `uvm_error("RST_CHK_ERR", 
                        $sformatf("读复位期间rempty应为1,实际为%b", vif.rempty))
                end
                
                // 读复位期间,读使能应无效(可选检查,取决于设计需求)
                if (vif.rinc === 1'b1) begin
                    `uvm_warning("RST_CHK_WARN", 
                        "读复位期间检测到有效读使能,可能导致非预期行为")
                end
            end
        end
    endtask
    
endclass
`endif

//  'fifo_chk_rst' 与 `fifo_rst_mon` 配合使用,专门验证异步FIFO在复位期间的行为是否符合设计规范,主要功能如下:

// 1. **复位状态接收**:
//    - 通过两个分析端口`wrst_imp`和`rrst_imp`接收来自复位监测器的复位状态
//    - 分别跟踪写复位(`wrst_active`)和读复位(`rrst_active`)的Active状态

// 2. **行为检查**:
//    - **写复位检查**:在写时钟域监测,确保写复位期间`wfull`信号为0(符合RTL设计)
//    - **读复位检查**:在读时钟域监测,确保读复位期间`rempty`信号为1(符合RTL设计)
//    - 可选检查:复位期间是否有无效的读写使能信号,发出警告提示

// 3. **跨时钟域适配**:
//    - 分别在写时钟(`wclk`)和读时钟(`rclk`)的下降沿进行检查,符合异步FIFO的跨时钟域特性
//    - 独立处理两个时钟域的复位行为,避免跨时钟域干扰

// 4. **错误报告**:
//    - 当检测到不符合预期的行为时,通过`uvm_error`报告错误
//    - 对潜在问题(如复位期间的使能信号)通过`uvm_warning`发出警告

// 该组件通过严格验证复位期间的关键信号状态,确保异步FIFO的复位功能符合设计要求
