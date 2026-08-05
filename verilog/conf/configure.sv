package configure;
  timeunit 1ns; timeprecision 1ps;

  localparam HARDWARE = 0;

  localparam PRF_DEPTH = 96;
  localparam ARCH_REGS = 32;
  localparam ROB_DEPTH = 32;
  localparam RS_INT_DEPTH = 16;
  localparam RS_MEM_DEPTH = 8;
  localparam FLIST_DEPTH = PRF_DEPTH - ARCH_REGS;

  localparam ISSUE_WIDTH = 4;
  localparam MEM_ISSUE_WIDTH = 2;

  localparam ALU_COUNT = ISSUE_WIDTH;
  localparam BCU_COUNT = 2;
  localparam MUL_COUNT = 2;
  localparam DIV_COUNT = 1;
  localparam BITALU_COUNT = 2;
  localparam CLMUL_COUNT = 1;
  localparam CSR_ALU_COUNT = 1;
  localparam LSU_COUNT = MEM_ISSUE_WIDTH;

  localparam AGU_BRANCH_COUNT = 2;
  localparam AGU_COUNT = AGU_BRANCH_COUNT + MEM_ISSUE_WIDTH;

  localparam TIM_WIDTH = 32;
  localparam TIM_DEPTH = 4096;

  localparam CACHE_WIDTH = 32;
  localparam CACHE_DEPTH = 4096;

  localparam BUFFER_WIDTH = 2 * CACHE_WIDTH;
  localparam BUFFER_DEPTH = 4;

  localparam PC_INCREMENTS = 4 * CACHE_WIDTH;

  localparam RAM_DEPTH = 262144;

  localparam BTAC_ENABLE = 1;
  localparam BTB_DEPTH = 512;
  localparam PHT_DEPTH = 1024;
  localparam BHT_DEPTH = 512;
  localparam BHT_WIDTH = $clog2(PHT_DEPTH);

  localparam ROM_BASE = 32'h00000000;
  localparam ROM_MASK = 32'hFFFFFF80;

  localparam SPI_BASE = 32'h00100000;
  localparam SPI_MASK = 32'hFFF00000;

  localparam UART_TX_BASE = 32'h01000000;
  localparam UART_TX_MASK = 32'hFFFFFFF0;

  localparam UART_RX_BASE = 32'h01000010;
  localparam UART_RX_MASK = 32'hFFFFFFF0;

  localparam CLINT_BASE = 32'h02000000;
  localparam CLINT_MASK = 32'hFFFF0000;

  localparam ITIM_BASE = 32'h10000000;
  localparam ITIM_MASK = 32'hFFF00000;

  localparam DTIM_BASE = 32'h20000000;
  localparam DTIM_MASK = 32'hFFF00000;

  localparam RAM_BASE = 32'h80000000;
  localparam RAM_MASK = 32'hFFF00000;

  localparam CPU_FREQ = 1000000000;
  localparam PER_FREQ = 200000000;
  localparam RTC_FREQ = 1000000;
  localparam BAUDRATE = 115200;

  localparam CLK_DIVIDER_PER = CPU_FREQ / PER_FREQ;
  localparam CLK_DIVIDER_RTC = CPU_FREQ / RTC_FREQ;
  localparam CLK_DIVIDER_BIT = CPU_FREQ / BAUDRATE;

endpackage
