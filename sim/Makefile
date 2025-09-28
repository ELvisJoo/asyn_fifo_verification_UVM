#!/usr/bin/make -f

# 进入sim目录:cd sim
# 编译并运行默认测试:make
# 运行指定测试:make run TEST=abnormal_test
# 查看波形:make verdi
# 清理文件:make clean

# 项目路径配置
TOP_MODULE      = top_tb                  # 顶层模块名
UVM_VER         = 1.1                     # UVM版本
WORK_DIR        = ./work                  # 工作目录
LOG_DIR         = ./log                   # 日志目录
WAVE_DIR        = ./wave                  # 波形目录
FILELIST        = ./filelist.f            # 文件列表路径

# 工具配置
VCS             = vcs
VERDI           = verdi
VCS_OPTS        = -sverilog -full64 -debug_access+all -UVM_VER=$(UVM_VER) \
                  +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm.sv \
                  +UVM_NO_RELNOTES +UVM_VERBOSITY=UVM_LOW \
                  -l $(LOG_DIR)/vcs_compile.log
VERDI_OPTS      = -sv -full64 -nologo -l $(LOG_DIR)/verdi.log

# 测试用例配置(默认运行基础测试)
TEST ?= base_test

# 创建目录
$(shell mkdir -p $(WORK_DIR) $(LOG_DIR) $(WAVE_DIR))

# 默认目标:编译并运行仿真
all: compile run

# 编译:生成可执行文件simv
compile:
	@echo "============================================="
	@echo "开始编译设计和验证环境..."
	@echo "测试用例: $(TEST)"
	@$(VCS) $(VCS_OPTS) -f $(FILELIST) -top $(TOP_MODULE) \
		+UVM_TESTNAME=$(TEST) -o $(WORK_DIR)/simv
	@echo "编译完成,可执行文件位于: $(WORK_DIR)/simv"
	@echo "============================================="

# 运行仿真
run:
	@echo "============================================="
	@echo "开始运行仿真..."
	@$(WORK_DIR)/simv +UVM_TESTNAME=$(TEST) \
		-l $(LOG_DIR)/sim_run_$(TEST).log
	@echo "仿真完成,日志文件位于: $(LOG_DIR)/sim_run_$(TEST).log"
	@echo "============================================="

# 查看波形
verdi:
	@echo "============================================="
	@echo "启动Verdi查看波形..."
	@$(VERDI) $(VERDI_OPTS) -f $(FILELIST) -top $(TOP_MODULE) \
		-ssf $(WAVE_DIR)/waveform.fsdb &
	@echo "Verdi启动完成"
	@echo "============================================="

# 清理中间文件
clean:
	@echo "============================================="
	@echo "清理中间文件..."
	@rm -rf $(WORK_DIR) $(LOG_DIR) $(WAVE_DIR)
	@rm -rf csrc simv* ucli.key vc_hdrs.h *.vpd *.fsdb
	@rm -rf verdiLog AN.DB
	@echo "清理完成"
	@echo "============================================="

# 伪目标声明
.PHONY: all compile run verdi clean
