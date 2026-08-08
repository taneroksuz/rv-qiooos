package wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam PRF_ADDR_BITS = $clog2(PRF_DEPTH);
  localparam ROB_ADDR_BITS = $clog2(ROB_DEPTH);
  localparam RS_ADDR_BITS = $clog2(RS_INT_DEPTH);
  localparam FL_CNT_BITS = $clog2(FLIST_DEPTH) + 1;
  localparam FL_IDX_BITS = $clog2(FLIST_DEPTH);
  localparam T_DEPTH = $clog2(PHT_DEPTH);

  typedef struct packed {
    logic [0:0] bit_sh1add;
    logic [0:0] bit_sh2add;
    logic [0:0] bit_sh3add;
  } zba_op_type;

  localparam zba_op_type init_zba_op = '{bit_sh1add: 0, bit_sh2add: 0, bit_sh3add: 0};

  typedef struct packed {
    logic [0:0] bit_andn;
    logic [0:0] bit_orn;
    logic [0:0] bit_xnor;
    logic [0:0] bit_clz;
    logic [0:0] bit_cpop;
    logic [0:0] bit_ctz;
    logic [0:0] bit_max;
    logic [0:0] bit_maxu;
    logic [0:0] bit_min;
    logic [0:0] bit_minu;
    logic [0:0] bit_orcb;
    logic [0:0] bit_rev8;
    logic [0:0] bit_rol;
    logic [0:0] bit_ror;
    logic [0:0] bit_sextb;
    logic [0:0] bit_sexth;
    logic [0:0] bit_zexth;
  } zbb_op_type;

  localparam zbb_op_type init_zbb_op = '{
      bit_andn: 0,
      bit_orn: 0,
      bit_xnor: 0,
      bit_clz: 0,
      bit_cpop: 0,
      bit_ctz: 0,
      bit_max: 0,
      bit_maxu: 0,
      bit_min: 0,
      bit_minu: 0,
      bit_orcb: 0,
      bit_rev8: 0,
      bit_rol: 0,
      bit_ror: 0,
      bit_sextb: 0,
      bit_sexth: 0,
      bit_zexth: 0
  };

  typedef struct packed {
    logic [0:0] bit_clmul_;
    logic [0:0] bit_clmulh;
    logic [0:0] bit_clmulr;
  } zbc_op_type;

  localparam zbc_op_type init_zbc_op = '{bit_clmul_: 0, bit_clmulh: 0, bit_clmulr: 0};

  typedef struct packed {
    logic [0:0] bit_bclr;
    logic [0:0] bit_bext;
    logic [0:0] bit_binv;
    logic [0:0] bit_bset;
  } zbs_op_type;

  localparam zbs_op_type init_zbs_op = '{bit_bclr: 0, bit_bext: 0, bit_binv: 0, bit_bset: 0};

  typedef struct packed {
    logic [0:0] bit_imm;
    logic [0:0] bit_alu_;
    logic [0:0] bit_clmul_;
    zba_op_type bit_zba;
    zbb_op_type bit_zbb;
    zbc_op_type bit_zbc;
    zbs_op_type bit_zbs;
  } bit_op_type;

  localparam bit_op_type init_bit_op = '{
      bit_imm: 0,
      bit_alu_: 0,
      bit_clmul_: 0,
      bit_zba: init_zba_op,
      bit_zbb: init_zbb_op,
      bit_zbc: init_zbc_op,
      bit_zbs: init_zbs_op
  };

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [31:0] imm;
    logic [0:0]  sel;
    bit_op_type  bit_op;
  } bit_alu_in_type;

  typedef struct packed {logic [31:0] result;} bit_alu_out_type;

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [0:0]  enable;
    zbc_op_type  op;
  } bit_clmul_in_type;

  typedef struct packed {
    logic [31:0] result;
    logic [0:0]  ready;
  } bit_clmul_out_type;

  typedef struct packed {
    logic [1:0]  state;
    logic [4:0]  counter;
    logic [5:0]  index;
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [31:0] swap;
    logic [31:0] result;
    logic [0:0]  ready;
    zbc_op_type  op;
  } bit_clmul_reg_type;

  localparam bit_clmul_reg_type init_bit_clmul_reg = '{
      state: 0,
      counter: 0,
      index: 0,
      rdata1: 0,
      rdata2: 0,
      swap: 0,
      result: 0,
      ready: 0,
      op: init_zbc_op
  };

  typedef struct packed {
    logic [0:0] alu_add;
    logic [0:0] alu_sub;
    logic [0:0] alu_sll;
    logic [0:0] alu_srl;
    logic [0:0] alu_sra;
    logic [0:0] alu_slt;
    logic [0:0] alu_sltu;
    logic [0:0] alu_and;
    logic [0:0] alu_or;
    logic [0:0] alu_xor;
  } alu_op_type;

  localparam alu_op_type init_alu_op = '{
      alu_add: 0,
      alu_sub: 0,
      alu_sll: 0,
      alu_srl: 0,
      alu_sra: 0,
      alu_slt: 0,
      alu_sltu: 0,
      alu_and: 0,
      alu_or: 0,
      alu_xor: 0
  };

  typedef struct packed {
    logic [0:0] divs;
    logic [0:0] divu;
    logic [0:0] rem;
    logic [0:0] remu;
  } div_op_type;

  localparam div_op_type init_div_op = '{divs: 0, divu: 0, rem: 0, remu: 0};

  typedef struct packed {
    logic [0:0] muls;
    logic [0:0] mulh;
    logic [0:0] mulhsu;
    logic [0:0] mulhu;
  } mul_op_type;

  localparam mul_op_type init_mul_op = '{muls: 0, mulh: 0, mulhsu: 0, mulhu: 0};

  typedef struct packed {
    logic [0:0] lsu_lb;
    logic [0:0] lsu_lbu;
    logic [0:0] lsu_lh;
    logic [0:0] lsu_lhu;
    logic [0:0] lsu_lw;
    logic [0:0] lsu_ld;
    logic [0:0] lsu_sb;
    logic [0:0] lsu_sh;
    logic [0:0] lsu_sw;
  } lsu_op_type;

  localparam lsu_op_type init_lsu_op = '{
      lsu_lb: 0,
      lsu_lbu: 0,
      lsu_lh: 0,
      lsu_lhu: 0,
      lsu_lw: 0,
      lsu_ld: 0,
      lsu_sb: 0,
      lsu_sh: 0,
      lsu_sw: 0
  };

  typedef struct packed {
    logic [0:0] bcu_beq;
    logic [0:0] bcu_bne;
    logic [0:0] bcu_blt;
    logic [0:0] bcu_bge;
    logic [0:0] bcu_bltu;
    logic [0:0] bcu_bgeu;
  } bcu_op_type;

  localparam bcu_op_type init_bcu_op = '{
      bcu_beq: 0,
      bcu_bne: 0,
      bcu_blt: 0,
      bcu_bge: 0,
      bcu_bltu: 0,
      bcu_bgeu: 0
  };

  typedef struct packed {
    logic [0:0] csrrw;
    logic [0:0] csrrs;
    logic [0:0] csrrc;
    logic [0:0] csrrwi;
    logic [0:0] csrrsi;
    logic [0:0] csrrci;
  } csr_op_type;

  localparam csr_op_type init_csr_op = '{
      csrrw: 0,
      csrrs: 0,
      csrrc: 0,
      csrrwi: 0,
      csrrsi: 0,
      csrrci: 0
  };

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [31:0] imm;
    logic [0:0]  sel;
    alu_op_type  alu_op;
  } alu_in_type;

  typedef struct packed {logic [31:0] result;} alu_out_type;

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [0:0]  enable;
    div_op_type  div_op;
  } div_in_type;

  typedef struct packed {
    logic [31:0] result;
    logic [0:0]  ready;
  } div_out_type;

  typedef struct packed {
    logic [31:0] data1;
    logic [31:0] data2;
    logic [31:0] op1;
    logic [31:0] op2;
    logic [0:0]  op1_signed;
    logic [0:0]  op2_signed;
    logic [0:0]  op1_neg;
    logic [5:0]  counter;
    logic [64:0] result;
    logic [0:0]  division;
    logic [0:0]  negativ;
    logic [0:0]  divisionbyzero;
    logic [0:0]  overflow;
    logic [0:0]  ready;
    div_op_type  div_op;
  } div_reg_type;

  localparam div_reg_type init_div_reg = '{
      data1: 0,
      data2: 0,
      op1: 0,
      op2: 0,
      op1_signed: 0,
      op2_signed: 0,
      op1_neg: 0,
      counter: 0,
      result: 0,
      division: 0,
      negativ: 0,
      divisionbyzero: 0,
      overflow: 0,
      ready: 0,
      div_op: init_div_op
  };

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    mul_op_type  mul_op;
  } mul_in_type;

  typedef struct packed {logic [31:0] result;} mul_out_type;

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [0:0]  enable;
    bcu_op_type  bcu_op;
  } bcu_in_type;

  typedef struct packed {logic [0:0] branch;} bcu_out_type;

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] imm;
    logic [31:0] pc;
    logic [0:0]  auipc;
    logic [0:0]  jal;
    logic [0:0]  jalr;
    logic [0:0]  branch;
    logic [0:0]  load;
    logic [0:0]  store;
    lsu_op_type  lsu_op;
  } agu_in_type;

  localparam agu_in_type init_agu_in = '{
      rdata1: 0,
      imm: 0,
      pc: 32'hFFFFFFFF,
      auipc: 0,
      jal: 0,
      jalr: 0,
      branch: 0,
      load: 0,
      store: 0,
      lsu_op: init_lsu_op
  };

  typedef struct packed {
    logic [31:0] address;
    logic [3:0]  byteenable;
    logic [0:0]  exception;
    logic [7:0]  ecause;
    logic [31:0] etval;
  } agu_out_type;

  localparam agu_out_type init_agu_out = '{
      address: 0,
      byteenable: 0,
      exception: 0,
      ecause: 0,
      etval: 0
  };

  typedef struct packed {
    logic [31:0] ldata;
    logic [3:0]  byteenable;
    lsu_op_type  lsu_op;
  } lsu_in_type;

  typedef struct packed {logic [31:0] result;} lsu_out_type;

  typedef struct packed {
    logic [31:0] cdata;
    logic [31:0] rdata1;
    logic [31:0] imm;
    logic [0:0]  sel;
    csr_op_type  csr_op;
  } csr_alu_in_type;

  typedef struct packed {logic [31:0] cdata;} csr_alu_out_type;

  typedef struct packed {
    logic [0:0]         taken;
    logic [31:0]        taddr;
    logic [1:0]         tsat;
    logic [T_DEPTH-1:0] thist;
  } prediction_type;

  localparam prediction_type init_prediction = '{taken: 0, taddr: 0, tsat: 0, thist: 0};

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][31:0]     get_pc;
    logic [ISSUE_WIDTH-1:0][31:0]     upd_pc;
    logic [ISSUE_WIDTH-1:0][31:0]     upd_npc;
    logic [ISSUE_WIDTH-1:0][31:0]     upd_addr;
    logic [ISSUE_WIDTH-1:0][0:0]      upd_jump;
    logic [ISSUE_WIDTH-1:0][0:0]      upd_branch;
    prediction_type [ISSUE_WIDTH-1:0] upd_pred;
  } btac_in_type;

  typedef struct packed {
    prediction_type [ISSUE_WIDTH-1:0] pred;
    logic [ISSUE_WIDTH-1:0][31:0]     pred_maddr;
    logic [ISSUE_WIDTH-1:0][0:0]      pred_miss;
  } btac_out_type;

  localparam btac_out_type init_btac_out = '{
      pred: '{default: init_prediction},
      pred_maddr: '{default: 0},
      pred_miss: '{default: 0}
  };

  typedef struct packed {
    logic [0:0] wren;
    logic [0:0] rden1;
    logic [0:0] rden2;
    logic [0:0] cwren;
    logic [0:0] crden;
    logic [0:0] alunit;
    logic [0:0] auipc;
    logic [0:0] lui;
    logic [0:0] jal;
    logic [0:0] jalr;
    logic [0:0] branch;
    logic [0:0] load;
    logic [0:0] store;
    logic [0:0] nop;
    logic [0:0] csreg;
    logic [0:0] division;
    logic [0:0] mult;
    logic [0:0] bitm;
    logic [0:0] bitc;
    logic [0:0] fence;
    logic [0:0] ecall;
    logic [0:0] ebreak;
    logic [0:0] mret;
    logic [0:0] wfi;
    logic [0:0] jump;
    logic [0:0] exception;
    logic [0:0] valid;
  } operation_type;

  localparam operation_type init_operation = '{
      wren: 0,
      rden1: 0,
      rden2: 0,
      cwren: 0,
      crden: 0,
      alunit: 0,
      auipc: 0,
      lui: 0,
      jal: 0,
      jalr: 0,
      branch: 0,
      load: 0,
      store: 0,
      nop: 0,
      csreg: 0,
      division: 0,
      mult: 0,
      bitm: 0,
      bitc: 0,
      fence: 0,
      ecall: 0,
      ebreak: 0,
      mret: 0,
      wfi: 0,
      jump: 0,
      exception: 0,
      valid: 0
  };

  typedef struct packed {
    logic [31:0]    pc;
    logic [31:0]    npc;
    logic [31:0]    instr;
    logic [79:0]    instr_str;
    logic [31:0]    imm;
    logic [4:0]     waddr;
    logic [4:0]     raddr1;
    logic [4:0]     raddr2;
    logic [4:0]     raddr3;
    logic [11:0]    caddr;
    logic [1:0]     fmt;
    logic [2:0]     rm;
    operation_type  op;
    alu_op_type     alu_op;
    bcu_op_type     bcu_op;
    lsu_op_type     lsu_op;
    csr_op_type     csr_op;
    div_op_type     div_op;
    mul_op_type     mul_op;
    bit_op_type     bit_op;
    prediction_type pred;
  } instruction_type;

  localparam instruction_type init_instruction = '{
      pc: 32'hFFFFFFFF,
      npc: 32'hFFFFFFFF,
      instr: 0,
      instr_str: "",
      imm: 0,
      waddr: 0,
      raddr1: 0,
      raddr2: 0,
      raddr3: 0,
      caddr: 0,
      fmt: 0,
      rm: 0,
      op: init_operation,
      alu_op: init_alu_op,
      bcu_op: init_bcu_op,
      lsu_op: init_lsu_op,
      csr_op: init_csr_op,
      div_op: init_div_op,
      mul_op: init_mul_op,
      bit_op: init_bit_op,
      pred: init_prediction
  };

  typedef struct packed {
    logic [0:0] rden1;
    logic [4:0] raddr1;
    logic [0:0] rden2;
    logic [4:0] raddr2;
  } register_read_in_type;

  typedef struct packed {
    logic [0:0]  wren;
    logic [4:0]  waddr;
    logic [31:0] wdata;
  } register_write_in_type;

  typedef struct packed {
    logic [31:0] rdata1;
    logic [31:0] rdata2;
  } register_out_type;

  typedef struct packed {
    logic [11:11] meip;
    logic [9:9]   seip;
    logic [8:8]   ueip;
    logic [7:7]   mtip;
    logic [5:5]   stip;
    logic [4:4]   utip;
    logic [3:3]   msip;
    logic [1:1]   ssip;
    logic [0:0]   usip;
  } csr_mip_reg_type;

  localparam csr_mip_reg_type init_csr_mip_reg = '{
      meip: 0,
      seip: 0,
      ueip: 0,
      mtip: 0,
      stip: 0,
      utip: 0,
      msip: 0,
      ssip: 0,
      usip: 0
  };

  typedef struct packed {
    logic [11:11] meie;
    logic [9:9]   seie;
    logic [8:8]   ueie;
    logic [7:7]   mtie;
    logic [5:5]   stie;
    logic [4:4]   utie;
    logic [3:3]   msie;
    logic [1:1]   ssie;
    logic [0:0]   usie;
  } csr_mie_reg_type;

  localparam csr_mie_reg_type init_csr_mie_reg = '{
      meie: 0,
      seie: 0,
      ueie: 0,
      mtie: 0,
      stie: 0,
      utie: 0,
      msie: 0,
      ssie: 0,
      usie: 0
  };

  typedef struct packed {
    logic [31:31] sd;
    logic [22:22] tsr;
    logic [21:21] tw;
    logic [20:20] tvm;
    logic [19:19] mxr;
    logic [18:18] summ;
    logic [17:17] mprv;
    logic [16:15] xs;
    logic [14:13] fs;
    logic [12:11] mpp;
    logic [8:8]   spp;
    logic [7:7]   mpie;
    logic [5:5]   spie;
    logic [4:4]   upie;
    logic [3:3]   mie;
    logic [1:1]   sie;
    logic [0:0]   uie;
  } csr_mstatus_reg_type;

  localparam csr_mstatus_reg_type init_csr_mstatus_reg = '{
      sd: 0,
      tsr: 0,
      tw: 0,
      tvm: 0,
      mxr: 0,
      summ: 0,
      mprv: 0,
      xs: 0,
      fs: 0,
      mpp: 0,
      spp: 0,
      mpie: 0,
      spie: 0,
      upie: 0,
      mie: 0,
      sie: 0,
      uie: 0
  };

  typedef struct packed {
    csr_mstatus_reg_type mstatus;
    logic [31:0]         mtvec;
    logic [63:0]         mcycle;
    logic [63:0]         minstret;
    logic [31:0]         mscratch;
    logic [31:0]         mepc;
    logic [31:0]         mcause;
    logic [31:0]         mtval;
    csr_mip_reg_type     mip;
    csr_mie_reg_type     mie;
    logic [31:0]         tselect;
    logic [31:0]         tdata1;
    logic [31:0]         tdata2;
    logic [31:0]         tcontrol;
  } csr_machine_reg_type;

  localparam csr_machine_reg_type init_csr_machine_reg = '{
      mstatus: init_csr_mstatus_reg,
      mtvec: 0,
      mscratch: 0,
      mepc: 0,
      mcause: 0,
      mtval: 0,
      mcycle: 0,
      minstret: 0,
      mip: init_csr_mip_reg,
      mie: init_csr_mie_reg,
      tselect: 0,
      tdata1: 0,
      tdata2: 0,
      tcontrol: 0
  };

  typedef struct packed {
    logic [0:0]  cwren;
    logic [11:0] cwaddr;
    logic [31:0] cdata;
  } csr_write_in_type;

  localparam csr_write_in_type init_csr_write_in = '{cwren: 0, cwaddr: 0, cdata: 0};

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][0:0] valid;
    logic [31:0]                 pc;
    logic [0:0]                  mret;
    logic [0:0]                  exception;
    logic [31:0]                 epc;
    logic [7:0]                  ecause;
    logic [31:0]                 etval;
  } csr_exception_in_type;

  localparam csr_exception_in_type init_csr_exception_in = '{
      valid: '{default: 0},
      pc: 0,
      mret: 0,
      exception: 0,
      epc: 0,
      ecause: 0,
      etval: 0
  };

  typedef struct packed {
    logic [0:0]  trap;
    logic [0:0]  mret;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] cdata;
    logic [1:0]  fs;
  } csr_out_type;

  typedef struct packed {
    logic [0:0]  crden;
    logic [11:0] craddr;
  } csr_read_in_type;

  typedef struct packed {
    logic [0:0]  cwren;
    logic [0:0]  crden;
    logic [11:0] cwaddr;
    logic [11:0] craddr;
    logic [31:0] cwdata;
    logic [1:0]  mode;
  } csr_pmp_in_type;

  typedef struct packed {
    logic [31:0] crdata;
    logic [0:0]  cready;
  } csr_pmp_out_type;

  typedef struct packed {
    logic [0:0]  mem_valid;
    logic [0:0]  mem_instr;
    logic [1:0]  mem_mode;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
  } mem_in_type;

  localparam mem_in_type init_mem_in = 0;

  typedef struct packed {
    logic [0:0]  mem_ready;
    logic [0:0]  mem_error;
    logic [31:0] mem_rdata;
  } mem_out_type;

  localparam mem_out_type init_mem_out = 0;

  typedef struct packed {
    logic [0:0]  mem_valid;
    logic [31:0] mem_addr;
  } cache_in_type;

  localparam cache_in_type init_cache_in = '{default: '0};

  typedef struct packed {
    logic [0:0]                mem_ready;
    logic [CACHE_WIDTH-1:0]    mem_error;
    logic [CACHE_WIDTH*32-1:0] mem_rdata;
  } cache_out_type;

  localparam cache_out_type init_cache_out = '{default: '0};

  typedef enum bit [1:0] {
    IDLE,
    BUSY,
    INVALID
  } fetch_state;

  typedef struct packed {
    fetch_state                   state;
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0][0:0]  lane_ready;
    logic [31:0]                  ipc;
    logic [CACHE_WIDTH*32-1:0]    rdata;
    logic [0:0]                   ready;
    logic [0:0]                   valid;
    logic [0:0]                   flush;
    logic [0:0]                   stall;
  } fetch_reg_type;

  localparam fetch_reg_type init_fetch_reg = '{
      state: IDLE,
      pc: '{default: 32'hFFFFFFFF},
      instr: '{default: 0},
      lane_ready: '{default: 0},
      ipc: 0,
      rdata: 0,
      ready: 0,
      valid: 0,
      flush: 0,
      stall: 0
  };

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0][0:0]  ready;
  } post_fetch_reg_type;

  localparam post_fetch_reg_type init_post_fetch_reg = '{
      pc: '{default: 32'hFFFFFFFF},
      instr: '{default: 0},
      ready: '{default: 0}
  };

  typedef struct packed {instruction_type [ISSUE_WIDTH-1:0] instr;} decode_reg_type;

  localparam decode_reg_type init_decode_reg = '{instr: '{default: init_instruction}};

  typedef struct packed {
    logic [0:0]               valid;
    logic [0:0]               done;
    logic [0:0]               exception;
    logic [7:0]               ecause;
    logic [31:0]              etval;
    logic [31:0]              pc;
    logic [31:0]              npc;
    logic [31:0]              pnpc;
    prediction_type           pred;
    logic [31:0]              result;
    logic [PRF_ADDR_BITS-1:0] pdest;
    logic [PRF_ADDR_BITS-1:0] old_pdest;
    logic [4:0]               adest;
    logic [0:0]               wren;
    logic [0:0]               store;
    logic [0:0]               load;
    logic [31:0]              store_addr;
    logic [31:0]              store_data;
    logic [3:0]               store_strb;
    lsu_op_type               lsu_op;
    logic [0:0]               branch;
    logic [0:0]               jump;
    logic [0:0]               mret;
    logic [0:0]               fence;
    logic [0:0]               ecall;
    logic [0:0]               ebreak;
    logic [0:0]               wfi;
    logic [0:0]               csreg;
    logic [0:0]               cwren;
    logic [11:0]              caddr;
    logic [31:0]              cwdata;
  } rob_entry_type;

  localparam rob_entry_type init_rob_entry = '{
      valid: 0,
      done: 0,
      exception: 0,
      ecause: 0,
      etval: 0,
      pc: 32'hFFFFFFFF,
      npc: 32'hFFFFFFFF,
      pnpc: 32'hFFFFFFFF,
      pred: init_prediction,
      result: 0,
      pdest: 0,
      old_pdest: 0,
      adest: 0,
      wren: 0,
      store: 0,
      load: 0,
      store_addr: 0,
      store_data: 0,
      store_strb: 0,
      lsu_op: init_lsu_op,
      branch: 0,
      jump: 0,
      mret: 0,
      fence: 0,
      ecall: 0,
      ebreak: 0,
      wfi: 0,
      csreg: 0,
      cwren: 0,
      caddr: 0,
      cwdata: 0
  };

  typedef struct packed {
    logic [0:0]               valid;
    logic [0:0]               src1_ready;
    logic [0:0]               src2_ready;
    logic [PRF_ADDR_BITS-1:0] psrc1;
    logic [PRF_ADDR_BITS-1:0] psrc2;
    logic [PRF_ADDR_BITS-1:0] pdest;
    logic [ROB_ADDR_BITS-1:0] rob_tag;
    logic [31:0]              rdata1;
    logic [31:0]              rdata2;
    logic [31:0]              imm;
    logic [31:0]              pc;
    logic [31:0]              npc;
    logic [11:0]              caddr;
    operation_type            op;
    alu_op_type               alu_op;
    bcu_op_type               bcu_op;
    lsu_op_type               lsu_op;
    csr_op_type               csr_op;
    div_op_type               div_op;
    mul_op_type               mul_op;
    bit_op_type               bit_op;
  } rs_entry_type;

  localparam rs_entry_type init_rs_entry = '{
      valid: 0,
      src1_ready: 0,
      src2_ready: 0,
      psrc1: 0,
      psrc2: 0,
      pdest: 0,
      rob_tag: 0,
      rdata1: 0,
      rdata2: 0,
      imm: 0,
      pc: 32'hFFFFFFFF,
      npc: 32'hFFFFFFFF,
      caddr: 0,
      op: init_operation,
      alu_op: init_alu_op,
      bcu_op: init_bcu_op,
      lsu_op: init_lsu_op,
      csr_op: init_csr_op,
      div_op: init_div_op,
      mul_op: init_mul_op,
      bit_op: init_bit_op
  };

  typedef struct packed {
    logic [0:0]  flush;
    logic [31:0] flush_pc;
  } commit_type;

  localparam commit_type init_commit = '{flush: 0, flush_pc: 0};

  typedef struct packed {
    logic [0:0]               valid;
    logic [PRF_ADDR_BITS-1:0] tag;
    logic [31:0]              data;
  } cdb_type;

  localparam cdb_type init_cdb = '{valid: 0, tag: 0, data: 0};

  typedef struct packed {
    logic [2*ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] raddr;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0]   waddr;
    logic [ISSUE_WIDTH-1:0][31:0]                wdata;
    logic [ISSUE_WIDTH-1:0][0:0]                 wren;
  } prf_in_type;

  typedef struct packed {
    logic [2*ISSUE_WIDTH-1:0][31:0] rdata;
    logic [2*ISSUE_WIDTH-1:0][0:0]  rvalid;
  } prf_out_type;

  localparam prf_in_type init_prf_in = 0;

  localparam prf_out_type init_prf_out = 0;

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][0:0]               alloc;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] free_tag;
    logic [ISSUE_WIDTH-1:0][0:0]               free_en;
  } fl_in_type;

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] alloc_tag;
    logic [ISSUE_WIDTH-1:0][0:0]               alloc_ok;
    logic [0:0]                                empty;
    logic [0:0]                                has_two;
  } fl_out_type;

  localparam fl_in_type init_fl_in = 0;

  localparam fl_out_type init_fl_out = 0;

  typedef struct packed {
    logic [2*ISSUE_WIDTH-1:0][4:0]             rsrc_a;
    logic [ISSUE_WIDTH-1:0][4:0]               waddr_a;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] waddr_p;
    logic [ISSUE_WIDTH-1:0][0:0]               wren;
    logic [ISSUE_WIDTH-1:0][4:0]               commit_addr;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] commit_tag;
    logic [ISSUE_WIDTH-1:0][0:0]               commit_en;
  } rat_in_type;

  typedef struct packed {
    logic [2*ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] psrc;
    logic [2*ISSUE_WIDTH-1:0][0:0]               psrc_valid;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0]   old_pdest;
  } rat_out_type;

  localparam rat_in_type init_rat_in = 0;

  localparam rat_out_type init_rat_out = 0;

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][0:0]                                 alloc;
    logic [0:0]                                                  store_ready;
    rob_entry_type [ISSUE_WIDTH-1:0]                             alloc_entry;
    logic [ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] write_tag;
    rob_entry_type [ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1:0]           write_entry;
    logic [ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1:0][0:0]               write_en;
    cdb_type [MEM_ISSUE_WIDTH-1:0]                               cdb;
  } rob_in_type;

  typedef struct packed {
    logic [ROB_ADDR_BITS-1:0]                  head_ptr;
    logic [ROB_ADDR_BITS-1:0]                  tail_ptr;
    logic [ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] alloc_tag;
    logic [0:0]                                full;
    logic [0:0]                                has_two_free;
    logic [ISSUE_WIDTH-1:0][0:0]               alloc_ok;
    commit_type                                commit_ctrl;
    rob_entry_type [ISSUE_WIDTH-1:0]           entry;
    logic [ISSUE_WIDTH-1:0][0:0]               commit;
    logic [0:0]                                stall;
  } rob_out_type;

  localparam rob_out_type init_rob_out = 0;

  typedef struct packed {
    rs_entry_type [ISSUE_WIDTH-1:0] entry;
    logic [ISSUE_WIDTH-1:0][0:0]    alloc;
    cdb_type [ISSUE_WIDTH-1:0]      cdb;
    cdb_type [MEM_ISSUE_WIDTH-1:0]  cdb_load;
    cdb_type [ISSUE_WIDTH-1:0]      cdb_commit;
    logic [ROB_ADDR_BITS-1:0]       rob_head;
    logic [MEM_ISSUE_WIDTH-1:0]     load_busy;
  } rs_mem_in_type;

  typedef struct packed {
    rs_entry_type [ISSUE_WIDTH-1:0] entry;
    logic [ISSUE_WIDTH-1:0][0:0]    alloc;
    cdb_type [ISSUE_WIDTH-1:0]      cdb;
    cdb_type [MEM_ISSUE_WIDTH-1:0]  cdb_load;
    cdb_type [ISSUE_WIDTH-1:0]      cdb_commit;
    logic [0:0]                     div_busy;
    logic [0:0]                     clmul_busy;
    logic [0:0]                     csr_commit;
    logic [ROB_ADDR_BITS-1:0]       rob_head;
  } rs_int_in_type;

  typedef struct packed {
    rs_entry_type [ISSUE_WIDTH-1:0] issue;
    logic [ISSUE_WIDTH-1:0][0:0]    issue_valid;
    logic [0:0]                     full;
    logic [0:0]                     has_two_free;
    logic [ISSUE_WIDTH-1:0][0:0]    alloc_ok;
    csr_read_in_type                csr_rin;
  } rs_int_out_type;

  typedef struct packed {
    rs_entry_type [MEM_ISSUE_WIDTH-1:0] issue;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]    issue_valid;
    logic [0:0]                         full;
    logic [0:0]                         has_two_free;
    logic [ISSUE_WIDTH-1:0][0:0]        alloc_ok;
  } rs_mem_out_type;

  typedef struct packed {
    instruction_type [ISSUE_WIDTH-1:0]         instr;
    logic [ISSUE_WIDTH-1:0][0:0]               instr_valid;
    logic [ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] rob_tag;
    logic [0:0]                                rob_full;
    logic [0:0]                                rob_has_two;
    logic [ISSUE_WIDTH-1:0][0:0]               rob_alloc_ok;
    rat_out_type                               rat;
    prf_out_type                               prf;
    fl_out_type                                fl;
    logic [0:0]                                rs_int_full;
    logic [0:0]                                rs_int_has_two;
    logic [ISSUE_WIDTH-1:0][0:0]               rs_int_alloc_ok;
    logic [0:0]                                rs_mem_full;
    logic [0:0]                                rs_mem_has_two;
    logic [ISSUE_WIDTH-1:0][0:0]               rs_mem_alloc_ok;
    cdb_type [ISSUE_WIDTH-1:0]                 cdb;
    cdb_type [MEM_ISSUE_WIDTH-1:0]             cdb_load;
  } rename_in_type;

  typedef struct packed {
    rs_entry_type [ISSUE_WIDTH-1:0]  rs_int_entry;
    logic [ISSUE_WIDTH-1:0][0:0]     rs_int_alloc;
    rs_entry_type [ISSUE_WIDTH-1:0]  rs_mem_entry;
    logic [ISSUE_WIDTH-1:0][0:0]     rs_mem_alloc;
    logic [ISSUE_WIDTH-1:0][0:0]     rob_alloc;
    rob_entry_type [ISSUE_WIDTH-1:0] rob_entry;
    rat_in_type                      rat;
    fl_in_type                       fl;
    logic [0:0]                      stall;
  } rename_out_type;

  typedef struct packed {
    rs_entry_type [ISSUE_WIDTH-1:0]     int_issue;
    logic [ISSUE_WIDTH-1:0][0:0]        int_issue_valid;
    rs_entry_type [MEM_ISSUE_WIDTH-1:0] mem_issue;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]    mem_issue_valid;
    csr_out_type                        csr;
    alu_out_type [ALU_COUNT-1:0]        alu_out;
    agu_out_type [AGU_COUNT-1:0]        agu_out;
    bcu_out_type [BCU_COUNT-1:0]        bcu_out;
    mul_out_type [MUL_COUNT-1:0]        mul_out;
    div_out_type                        div_out;
    bit_alu_out_type [BITALU_COUNT-1:0] bit_alu_out;
    bit_clmul_out_type                  bit_clmul_out;
    csr_alu_out_type                    csr_alu_out;
  } eu_in_type;

  typedef struct packed {
    alu_in_type [ALU_COUNT-1:0]                    alu_in;
    agu_in_type [AGU_COUNT-1:0]                    agu_in;
    bcu_in_type [BCU_COUNT-1:0]                    bcu_in;
    mul_in_type [MUL_COUNT-1:0]                    mul_in;
    div_in_type                                    div_in;
    bit_alu_in_type [BITALU_COUNT-1:0]             bit_alu_in;
    bit_clmul_in_type                              bit_clmul_in;
    csr_alu_in_type                                csr_alu_in;
    cdb_type [ISSUE_WIDTH-1:0]                     cdb;
    logic [ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0]     rob_wtag;
    rob_entry_type [ISSUE_WIDTH-1:0]               rob_wentry;
    logic [ISSUE_WIDTH-1:0][0:0]                   rob_wen;
    logic [MEM_ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] rob_wtag_store;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0]           rob_wentry_store;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]               rob_wen_store;
    logic [0:0]                                    div_busy;
    logic [0:0]                                    clmul_busy;
  } eu_out_type;

  typedef struct packed {
    rs_entry_type [MEM_ISSUE_WIDTH-1:0]  issue;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]     issue_valid;
    agu_out_type [MEM_ISSUE_WIDTH-1:0]   agu_out;
    lsu_out_type [LSU_COUNT-1:0]         lsu_out;
    mem_out_type [LSU_COUNT-1:0]         dmem_out;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]     commit_store;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0] commit_entry;
  } msu_in_type;

  localparam msu_in_type init_msu_in = '{
      issue: '{default: init_rs_entry},
      issue_valid: '{default: 0},
      agu_out: '{default: init_agu_out},
      lsu_out: '{default: '{result: 0}},
      dmem_out: '{default: init_mem_out},
      commit_store: '{default: 0},
      commit_entry: '{default: init_rob_entry}
  };

  typedef struct packed {
    cdb_type [MEM_ISSUE_WIDTH-1:0]                 cdb;
    logic [MEM_ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] rob_wtag;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0]           rob_wentry;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]               rob_wen;
    logic [MEM_ISSUE_WIDTH-1:0]                    load_busy;
    logic [0:0]                                    store_ready;
    mem_in_type [LSU_COUNT-1:0]                    dmem_in;
    lsu_in_type [LSU_COUNT-1:0]                    lsu_in;
  } msu_out_type;

  localparam msu_out_type init_msu_out = '{
      cdb: '{default: init_cdb},
      rob_wtag: '{default: '0},
      rob_wentry: '{default: init_rob_entry},
      rob_wen: '{default: 0},
      load_busy: 0,
      store_ready: 1,
      dmem_in: '{default: init_mem_in},
      lsu_in: '{default: '{ldata: 0, byteenable: 0, lsu_op: init_lsu_op}}
  };

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][0:0]     commit;
    commit_type                      commit_ctrl;
    rob_entry_type [ISSUE_WIDTH-1:0] entry;
    csr_out_type                     csr_o;
    btac_out_type                    btac_out;
  } commit_in_type;

  localparam commit_in_type init_commit_in = '{
      commit: '{default: 0},
      commit_ctrl: init_commit,
      entry: '{default: init_rob_entry},
      csr_o: '{trap: 0, mret: 0, mtvec: 0, mepc: 0, cdata: 0, fs: 0},
      btac_out: init_btac_out
  };

  typedef struct packed {
    register_write_in_type [ISSUE_WIDTH-1:0] register_win;
    csr_write_in_type                        csr_win;
    csr_exception_in_type                    csr_ein;
    rat_in_type                              rat_i;
    prf_in_type                              prf_i;
    fl_in_type                               fl_i;
    logic [0:0]                              flush;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]         commit_store;
    rob_entry_type [ISSUE_WIDTH-1:0]         commit_entry;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]         store_slot_valid;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0]     store_slot_entry;
  } commit_out_type;

  localparam commit_out_type init_commit_out = '{
      register_win: '{default: '{wren: 0, waddr: 0, wdata: 0}},
      csr_win: init_csr_write_in,
      csr_ein: init_csr_exception_in,
      rat_i: init_rat_in,
      prf_i: init_prf_in,
      fl_i: init_fl_in,
      flush: 0,
      commit_store: '{default: 0},
      commit_entry: '{default: init_rob_entry},
      store_slot_valid: '{default: 0},
      store_slot_entry: '{default: init_rob_entry}
  };

  typedef struct packed {logic [31:0] instr;} base_in_type;

  typedef struct packed {
    logic [79:0] instr_str;
    logic [31:0] imm;
    logic [0:0]  wren;
    logic [0:0]  rden1;
    logic [0:0]  rden2;
    logic [0:0]  cwren;
    logic [0:0]  crden;
    logic [0:0]  alunit;
    logic [0:0]  auipc;
    logic [0:0]  lui;
    logic [0:0]  jal;
    logic [0:0]  jalr;
    logic [0:0]  branch;
    logic [0:0]  load;
    logic [0:0]  store;
    logic [0:0]  nop;
    logic [0:0]  csreg;
    logic [0:0]  division;
    logic [0:0]  mult;
    logic [0:0]  bitm;
    logic [0:0]  bitc;
    logic [0:0]  fence;
    logic [0:0]  ecall;
    logic [0:0]  ebreak;
    logic [0:0]  mret;
    logic [0:0]  wfi;
    logic [0:0]  valid;
    alu_op_type  alu_op;
    bcu_op_type  bcu_op;
    lsu_op_type  lsu_op;
    csr_op_type  csr_op;
    div_op_type  div_op;
    mul_op_type  mul_op;
    bit_op_type  bit_op;
  } base_out_type;

  typedef struct packed {logic [31:0] instr;} compress_in_type;

  typedef struct packed {
    logic [79:0] instr_str;
    logic [31:0] imm;
    logic [4:0]  waddr;
    logic [4:0]  raddr1;
    logic [4:0]  raddr2;
    logic [0:0]  wren;
    logic [0:0]  rden1;
    logic [0:0]  rden2;
    logic [0:0]  alunit;
    logic [0:0]  lui;
    logic [0:0]  jal;
    logic [0:0]  jalr;
    logic [0:0]  branch;
    logic [0:0]  load;
    logic [0:0]  store;
    logic [0:0]  nop;
    logic [0:0]  ebreak;
    logic [0:0]  valid;
    alu_op_type  alu_op;
    bcu_op_type  bcu_op;
    lsu_op_type  lsu_op;
  } compress_out_type;

  typedef struct packed {
    logic [31:0]               pc;
    logic [CACHE_WIDTH*32-1:0] rdata;
    logic [0:0]                ready;
    logic [0:0]                clear;
    logic [0:0]                stall;
  } buffer_in_type;

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0][0:0]  ready;
    logic [0:0]                   stall;
  } buffer_out_type;

  typedef struct packed {
    csr_out_type                     csr_out;
    btac_out_type                    btac_out;
    cache_out_type                   cache_out;
    buffer_out_type                  buffer_out;
    rob_entry_type [ISSUE_WIDTH-1:0] entry;
  } fetch_in_type;

  typedef struct packed {
    buffer_in_type                buffer_in;
    btac_in_type                  btac_in;
    cache_in_type                 cache_in;
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0][0:0]  ready;
  } fetch_out_type;

  typedef struct packed {
    btac_out_type                 btac_out;
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0][0:0]  ready;
  } post_fetch_in_type;

  typedef struct packed {
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0][0:0]  ready;
  } post_fetch_out_type;

  typedef struct packed {
    base_out_type [ISSUE_WIDTH-1:0]     base_out;
    compress_out_type [ISSUE_WIDTH-1:0] compress_out;
    btac_out_type                       btac_out;
    logic [ISSUE_WIDTH-1:0][31:0]       pc;
    logic [ISSUE_WIDTH-1:0][31:0]       instr;
    logic [ISSUE_WIDTH-1:0][0:0]        ready;
  } decode_in_type;

  typedef struct packed {
    base_in_type [ISSUE_WIDTH-1:0]     base_in;
    compress_in_type [ISSUE_WIDTH-1:0] compress_in;
    instruction_type [ISSUE_WIDTH-1:0] instr;
  } decode_out_type;

endpackage
