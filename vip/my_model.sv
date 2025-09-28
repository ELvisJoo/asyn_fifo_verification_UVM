`ifndef MY_MODEL_SV
`define MY_MODEL_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "./vip/my_transaction.sv"

// 1. 定义专用的分析端口类型
typedef uvm_analysis_port #(my_transaction) my_analysis_port;
typedef uvm_blocking_get_port #(my_transaction) my_blocking_get_port;


// 针对UVM 1.1d版本兼容性的宏定义
`ifndef UVM_COMPONENT_UTILS_PARAM
`define uvm_component_utils_param(T) \
  typedef uvm_component_registry#(T, `"T`") type_id; \
  static function type_id get_type(); \
    return type_id::get(); \
  endfunction \
  virtual function uvm_object_wrapper get_object_type(); \
    return type_id::get(); \
  endfunction
`endif

// 正确的参数化类声明方式
class my_model #(parameter ADDRSIZEL=4, parameter DATASIZEL=8) extends uvm_component;
 
    localparam DEPTH = 1 << ADDRSIZEL;  // FIFO深度

    // 同步寄存器(修复非阻塞赋值错误)
    logic [ADDRSIZEL:0]   wq1_rptr, rq1_wptr;


    // 使用预定义的端口类型
    my_blocking_get_port w_port;    // 接收写事务
    my_analysis_port r_port;        // 发送读结果
    
    // 内部存储和指针(模拟RTL行为)
    logic [DATASIZEL-1:0] mem [0:DEPTH-1];  // 模拟双端口RAM
    logic [ADDRSIZEL:0]   wptr, rptr;       // 写指针和读指针(格雷码)
    logic [ADDRSIZEL:0]   wq2_rptr;         // 同步到写时钟域的读指针
    logic [ADDRSIZEL:0]   rq2_wptr;         // 同步到读时钟域的写指针
    logic [ADDRSIZEL:0]   wbin, rbin;       // 二进制指针
    logic                 wfull, rempty;    // 空满标志
    
    // 内部事件和线程控制
    event w_phase_done;
    event r_phase_done;
    
    // 使用兼容UVM 1.1d的参数化类注册宏
    `uvm_component_utils_param(my_model#(ADDRSIZEL, DATASIZEL))
    
    function new(string name = "my_model", uvm_component parent = null);
        super.new(name, parent);
        w_port = new("w_port", this);
        r_port = new("r_port", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 初始化指针和存储
        initialize();
    endfunction
    
    // 初始化函数
    virtual function void initialize();
        foreach(mem[i]) mem[i] = '0;
        wptr = '0;
        rptr = '0;
        wbin = '0;
        rbin = '0;
        wq1_rptr = '0;
        wq2_rptr = '0;
        rq1_wptr = '0;
        rq2_wptr = '0;
        wfull = 1'b0;
        rempty = 1'b1;  // 初始为空
    endfunction
    
    // 主任务:分离的写时钟域和读时钟域处理
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        // 启动写时钟域和读时钟域的处理线程
        fork
            write_thread();  // 模拟写时钟域操作
            read_thread();   // 模拟读时钟域操作
            sync_thread();   // 模拟指针同步
        join
    endtask
    
    // 写时钟域处理线程
    virtual task write_thread();
        my_transaction w_tr;
        forever begin
            // 从输入端口获取写事务
            w_port.get(w_tr);
            
            // 处理写操作(模拟写时钟域行为)
            if (w_tr.winc && !wfull) begin
                // 写入数据到RAM
                mem[wbin[ADDRSIZEL-1:0]] = w_tr.wdata;
                
                // 更新二进制写指针
                wbin = wbin + 1'b1;
                
                // 二进制转格雷码
                wptr = (wbin >> 1) ^ wbin;
                
                `uvm_info("MODEL_WRITE", 
                    $sformatf("写入数据: addr=0x%0h, data=0x%0h, wptr=0x%0h", 
                    wbin[ADDRSIZEL-1:0], w_tr.wdata, wptr), UVM_HIGH)
            end
            
            // 更新满标志
            update_wfull();
            
            // 将写操作信息传递给事务(用于监测)
            w_tr.wfull = wfull;
            
            -> w_phase_done;
        end
    endtask
    
    // 读时钟域处理线程
    virtual task read_thread();
        forever begin
            my_transaction r_tr = my_transaction::type_id::create("r_tr");
            
            // 处理读操作(模拟读时钟域行为)
            if (!rempty) begin
                // 从RAM读取数据
                r_tr.rdata = mem[rbin[ADDRSIZEL-1:0]];
                
                // 读使能有效时更新读指针
                if (r_tr.rinc) begin
                    // 更新二进制读指针
                    rbin = rbin + 1'b1;
                    
                    // 二进制转格雷码
                    rptr = (rbin >> 1) ^ rbin;
                    
                    `uvm_info("MODEL_READ", 
                        $sformatf("读出数据: addr=0x%0h, data=0x%0h, rptr=0x%0h", 
                        rbin[ADDRSIZEL-1:0]-1, r_tr.rdata, rptr), UVM_HIGH)
                end
            end
            else begin
                r_tr.rdata = '0;  // 空状态时读数据为0
                `uvm_info("MODEL_READ", "FIFO为空,无法读取数据", UVM_HIGH)
            end
            
            // 更新空标志
            update_rempty();
            
            // 设置事务的其他字段
            r_tr.rempty = rempty;
            
            // 发送预期的读结果
            r_port.write(r_tr);
            
            -> r_phase_done;
        end
    endtask
    
    // 模拟指针同步(两级同步)
    virtual task sync_thread();
        
        forever begin
            // 读指针同步到写时钟域(两级同步)
            wq1_rptr <= rptr;
            wq2_rptr <= wq1_rptr;
            
            // 写指针同步到读时钟域(两级同步)
            rq1_wptr <= wptr;
            rq2_wptr <= rq1_wptr;
            
            @(posedge w_phase_done or posedge r_phase_done);
        end
    endtask
    
    // 更新满标志(与RTL逻辑一致)
    virtual function void update_wfull();
        wfull = (wptr == {~wq2_rptr[ADDRSIZEL : ADDRSIZEL-1], 
                          wq2_rptr[ADDRSIZEL-2 : 0]});
    endfunction
    
    // 更新空标志(与RTL逻辑一致)
    virtual function void update_rempty();
        rempty = (rptr == rq2_wptr);
    endfunction
    
    // 复位处理
    virtual function void reset();
        initialize();
        `uvm_info("MODEL_RESET", "模型已复位", UVM_MEDIUM)
    endfunction

endclass

`endif

// 这个参考模型`my_model.sv`按照RTL的功能实现,主要特点如下:

// 1. **结构对应**:
//    - 包含与RTL完全一致的参数(`ADDRSIZEL`、`DATASIZEL`)和内部信号
//    - 模拟了双端口RAM、读写指针、同步指针和空满标志等核心组件

// 2. **功能模拟**:
//    - **存储单元**:使用`mem`数组模拟RTL中的双端口RAM
//    - **指针管理**:实现了二进制指针和格雷码指针的转换逻辑
//    - **同步机制**:模拟了读写指针的两级同步过程(`sync_r2w`和`sync_w2r`)
//    - **空满判断**:完全复现了RTL中的空满标志生成逻辑

// 3. **线程分离**:
//    - 采用分离的`write_thread`和`read_thread`模拟异步时钟域操作
//    - `sync_thread`专门处理指针同步,与RTL的同步模块行为一致

// 4. **TLM通信**:
//    - 通过`w_port`接收写事务(来自i_agent)
//    - 通过`r_port`发送预期的读结果(到scoreboard)

// 5. **可验证性**:
//    - 详细的日志信息帮助调试
//    - 与RTL一致的空满判断逻辑,确保行为匹配
//    - 包含复位功能,支持复位测试场景

// 该组件可以作为"参考模型"与DUT的实际输出进行对比,有效验证异步FIFO的功能正确性,包括跨时钟域数据传输、空满状态判断等关键特性。