import configure::*;
import constants::*;
import wires::*;
import functions::*;

module eu (
  input  logic       reset,
  input  logic       clock,
  input  logic       flush,
  input  eu_in_type  eu_in,
  output eu_out_type eu_out
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    cdb_type [ISSUE_WIDTH-1:0]                     cdb;
    logic [ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0]     rob_wtag;
    rob_entry_type [ISSUE_WIDTH-1:0]               rob_wentry;
    logic [ISSUE_WIDTH-1:0]                        rob_wen;
    logic [MEM_ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] rob_wtag_store;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0]           rob_wentry_store;
    logic [MEM_ISSUE_WIDTH-1:0]                    rob_wen_store;
    rs_entry_type                                  div_pending;
    logic [0:0]                                    div_pending_valid;

    rs_entry_type [ISSUE_WIDTH-1:0] int_issue;
    logic [ISSUE_WIDTH-1:0]         int_issue_valid;

    logic [ISSUE_WIDTH-1:0][31:0] agu_result_lane;
    logic [ISSUE_WIDTH-1:0]       agu_exception_lane;
    logic [ISSUE_WIDTH-1:0][7:0]  agu_ecause_lane;
    logic [ISSUE_WIDTH-1:0][31:0] agu_etval_lane;
    logic [ISSUE_WIDTH-1:0][31:0] mul_result_lane;
    logic [ISSUE_WIDTH-1:0][31:0] bit_result_lane;
    logic [ISSUE_WIDTH-1:0]       branch_taken_lane;
    logic [ISSUE_WIDTH-1:0][31:0] eu_result_lane;
    logic [ISSUE_WIDTH-1:0]       eu_done_lane;
    logic [ISSUE_WIDTH-1:0]       agu_need;

    logic [AGU_BRANCH_COUNT-1:0][1:0] agu_owner;
    logic [AGU_BRANCH_COUNT-1:0]      agu_found;
    logic [BCU_COUNT-1:0][1:0]        bcu_owner;
    logic [BCU_COUNT-1:0]             bcu_found;
    logic [MUL_COUNT-1:0][1:0]        mul_owner;
    logic [MUL_COUNT-1:0]             mul_found;
    logic [BITALU_COUNT-1:0][1:0]     bitalu_owner;
    logic [BITALU_COUNT-1:0]          bitalu_found;

    logic [1:0]  csr_owner;
    logic [0:0]  csr_found;
    csr_op_type  csr_owner_op;
    logic [31:0] csr_result;

    logic [MEM_ISSUE_WIDTH-1:0][31:0] mstore_data;
    lsu_op_type [MEM_ISSUE_WIDTH-1:0] mem_lsu_op;
    logic [ISSUE_WIDTH-1:0]           div_issue;
    logic [ISSUE_WIDTH-1:0][31:0]     npc_lane;
  } eu_reg_type;

  localparam eu_reg_type init_eu_reg = '{
      cdb               : '{default: init_cdb},
      rob_wtag          : '{default: '0},
      rob_wentry        : '{default: init_rob_entry},
      rob_wen           : '{default: 1'b0},
      rob_wtag_store    : '{default: '0},
      rob_wentry_store  : '{default: init_rob_entry},
      rob_wen_store     : '{default: 1'b0},
      div_pending        : init_rs_entry,
      div_pending_valid  : 0,
      int_issue          : '{default: init_rs_entry},
      default: '0
  };

  eu_reg_type r, rin;
  eu_reg_type v;

  always_comb begin

    v = r;

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.cdb[l]        = init_cdb;
      v.rob_wtag[l]   = eu_in.int_issue[l].rob_tag;
      v.rob_wentry[l] = init_rob_entry;
      v.rob_wen[l]    = 1'b0;
    end
    for (int l = 0; l < MEM_ISSUE_WIDTH; l++) begin
      v.rob_wtag_store[l]   = eu_in.mem_issue[l].rob_tag;
      v.rob_wentry_store[l] = init_rob_entry;
      v.rob_wen_store[l]    = 1'b0;
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.int_issue[l]       = eu_in.int_issue[l];
      v.int_issue_valid[l] = eu_in.int_issue_valid[l];
      v.npc_lane[l]        = rs_npc(eu_in.int_issue[l]);
    end

    v.div_issue[0] = eu_in.int_issue_valid[0] &
        eu_in.int_issue[0].op.division & ~r.div_pending_valid;
    for (int l = 1; l < ISSUE_WIDTH; l++) begin
      v.div_issue[l] = eu_in.int_issue_valid[l] &
          eu_in.int_issue[l].op.division & ~r.div_pending_valid;
      for (int j = 0; j < l; j++) begin
        v.div_issue[l] = v.div_issue[l] & ~v.div_issue[j];
      end
    end

    if (flush) begin
      v.div_pending_valid = 1'b0;
    end else begin
      if (eu_in.div_out.ready) begin
        v.div_pending_valid = 1'b0;
      end else begin
        for (int l = 0; l < ISSUE_WIDTH; l++) begin
          if (v.div_issue[l]) begin
            v.div_pending       = eu_in.int_issue[l];
            v.div_pending_valid = 1'b1;
          end
        end
      end
    end

    for (int l = 0; l < ALU_COUNT; l++) begin
      eu_out.alu_in[l].rdata1 = v.int_issue[l].rdata1;
      eu_out.alu_in[l].rdata2 = v.int_issue[l].rdata2;
      eu_out.alu_in[l].imm    = v.int_issue[l].imm;
      eu_out.alu_in[l].sel    = v.int_issue[l].op.rden2;
      eu_out.alu_in[l].alu_op = rs_alu_op(v.int_issue[l].unit_op);
    end

    for (int l = 0; l < MEM_ISSUE_WIDTH; l++) begin
      eu_out.agu_in[AGU_BRANCH_COUNT+l].rdata1 = eu_in.mem_issue[l].rdata1;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].imm    = eu_in.mem_issue[l].imm;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].pc     = eu_in.mem_issue[l].pc;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].auipc  = 1'b0;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].jal    = 1'b0;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].jalr   = 1'b0;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].branch = 1'b0;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].load   = eu_in.mem_issue[l].op.load;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].store  = eu_in.mem_issue[l].op.store;
      eu_out.agu_in[AGU_BRANCH_COUNT+l].lsu_op = rs_lsu_op(eu_in.mem_issue[l].unit_op);
    end

    for (int p = 0; p < AGU_BRANCH_COUNT; p++) begin
      v.agu_found[p] = 1'b0;
      v.agu_owner[p] = 2'(0);
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.agu_need[l] = v.int_issue_valid[l] && (v.int_issue[l].op.auipc || v.int_issue[l].op.jal ||
                                               v.int_issue[l].op.jalr || v.int_issue[l].op.branch);
      if (v.agu_need[l]) begin
        for (int p = 0; p < AGU_BRANCH_COUNT; p++) begin
          if (!v.agu_found[p]) begin
            v.agu_owner[p] = 2'(l);
            v.agu_found[p] = 1'b1;
            break;
          end
        end
      end
    end

    for (int p = 0; p < AGU_BRANCH_COUNT; p++) begin
      eu_out.agu_in[p].rdata1 = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].rdata1 : 32'h0;
      eu_out.agu_in[p].imm    = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].imm : 32'h0;
      eu_out.agu_in[p].pc     = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].pc : 32'h0;
      eu_out.agu_in[p].auipc  = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].op.auipc : 1'b0;
      eu_out.agu_in[p].jal    = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].op.jal : 1'b0;
      eu_out.agu_in[p].jalr   = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].op.jalr : 1'b0;
      eu_out.agu_in[p].branch = v.agu_found[p] ? v.int_issue[v.agu_owner[p]].op.branch : 1'b0;
      eu_out.agu_in[p].load   = 1'b0;
      eu_out.agu_in[p].store  = 1'b0;
      eu_out.agu_in[p].lsu_op = init_lsu_op;
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.agu_result_lane[l]    = v.npc_lane[l];
      v.agu_exception_lane[l] = 1'b0;
      v.agu_ecause_lane[l]    = '0;
      v.agu_etval_lane[l]     = 32'h0;
      for (int p = 0; p < AGU_BRANCH_COUNT; p++) begin
        if (v.agu_found[p] && (v.agu_owner[p] == 2'(l))) begin
          v.agu_result_lane[l]    = eu_in.agu_out[p].address;
          v.agu_exception_lane[l] = eu_in.agu_out[p].exception;
          v.agu_ecause_lane[l]    = eu_in.agu_out[p].ecause;
          v.agu_etval_lane[l]     = eu_in.agu_out[p].etval;
        end
      end
    end

    for (int p = 0; p < BCU_COUNT; p++) begin
      v.bcu_found[p] = 1'b0;
      v.bcu_owner[p] = 2'(0);
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      if (v.int_issue_valid[l] && v.int_issue[l].op.branch) begin
        for (int p = 0; p < BCU_COUNT; p++) begin
          if (!v.bcu_found[p]) begin
            v.bcu_owner[p] = 2'(l);
            v.bcu_found[p] = 1'b1;
            break;
          end
        end
      end
    end

    for (int p = 0; p < BCU_COUNT; p++) begin
      eu_out.bcu_in[p].rdata1 = v.bcu_found[p] ? v.int_issue[v.bcu_owner[p]].rdata1 : 32'h0;
      eu_out.bcu_in[p].rdata2 = v.bcu_found[p] ? v.int_issue[v.bcu_owner[p]].rdata2 : 32'h0;
      eu_out.bcu_in[p].enable = v.bcu_found[p];
      eu_out.bcu_in[p].bcu_op = v.bcu_found[p] ? rs_bcu_op(v.int_issue[v.bcu_owner[p]].unit_op) :
          init_bcu_op;
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.branch_taken_lane[l] = 1'b0;
      for (int p = 0; p < BCU_COUNT; p++) begin
        if (v.bcu_found[p] && (v.bcu_owner[p] == 2'(l))) begin
          v.branch_taken_lane[l] = v.int_issue[l].op.branch & eu_in.bcu_out[p].branch;
        end
      end
    end

    for (int p = 0; p < MUL_COUNT; p++) begin
      v.mul_found[p] = 1'b0;
      v.mul_owner[p] = 2'(0);
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      if (v.int_issue_valid[l] && v.int_issue[l].op.mult) begin
        for (int p = 0; p < MUL_COUNT; p++) begin
          if (!v.mul_found[p]) begin
            v.mul_owner[p] = 2'(l);
            v.mul_found[p] = 1'b1;
            break;
          end
        end
      end
    end

    for (int p = 0; p < MUL_COUNT; p++) begin
      eu_out.mul_in[p].rdata1 = v.mul_found[p] ? v.int_issue[v.mul_owner[p]].rdata1 : 32'h0;
      eu_out.mul_in[p].rdata2 = v.mul_found[p] ? v.int_issue[v.mul_owner[p]].rdata2 : 32'h0;
      eu_out.mul_in[p].mul_op = v.mul_found[p] ? rs_mul_op(v.int_issue[v.mul_owner[p]].unit_op) :
          init_mul_op;
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.mul_result_lane[l] = 32'h0;
      for (int p = 0; p < MUL_COUNT; p++) begin
        if (v.mul_found[p] && (v.mul_owner[p] == 2'(l))) begin
          v.mul_result_lane[l] = eu_in.mul_out[p].result;
        end
      end
    end

    for (int p = 0; p < BITALU_COUNT; p++) begin
      v.bitalu_found[p] = 1'b0;
      v.bitalu_owner[p] = 2'(0);
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      if (v.int_issue_valid[l] && v.int_issue[l].op.bitm) begin
        for (int p = 0; p < BITALU_COUNT; p++) begin
          if (!v.bitalu_found[p]) begin
            v.bitalu_owner[p] = 2'(l);
            v.bitalu_found[p] = 1'b1;
            break;
          end
        end
      end
    end

    for (int p = 0; p < BITALU_COUNT; p++) begin
      eu_out.bit_alu_in[p].rdata1 = v.bitalu_found[p] ? v.int_issue[v.bitalu_owner[p]].rdata1 :
          32'h0;
      eu_out.bit_alu_in[p].rdata2 = v.bitalu_found[p] ? v.int_issue[v.bitalu_owner[p]].rdata2 :
          32'h0;
      eu_out.bit_alu_in[p].imm = v.bitalu_found[p] ? v.int_issue[v.bitalu_owner[p]].imm : 32'h0;
      eu_out.bit_alu_in[p].sel = v.bitalu_found[p] ? v.int_issue[v.bitalu_owner[p]].op.rden2 : 1'b0;
      eu_out.bit_alu_in[p].bit_op = v.bitalu_found[p] ?
          rs_bit_op(v.int_issue[v.bitalu_owner[p]].unit_op) : init_bit_op;
    end

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.bit_result_lane[l] = 32'h0;
      for (int p = 0; p < BITALU_COUNT; p++) begin
        if (v.bitalu_found[p] && (v.bitalu_owner[p] == 2'(l))) begin
          v.bit_result_lane[l] = eu_in.bit_alu_out[p].result;
        end
      end
    end

    v.csr_found = 1'b0;
    v.csr_owner = 0;

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      if (v.int_issue_valid[l] && v.int_issue[l].op.csreg && !v.csr_found) begin
        v.csr_owner = 2'(l);
        v.csr_found = 1'b1;
      end
    end

    eu_out.csr_alu_in.cdata = eu_in.csr.cdata;
    eu_out.csr_alu_in.rdata1 = v.csr_found ? v.int_issue[v.csr_owner].rdata1 : 32'h0;
    eu_out.csr_alu_in.imm = v.csr_found ? v.int_issue[v.csr_owner].imm : 32'h0;
    v.csr_owner_op = rs_csr_op(v.int_issue[v.csr_owner].unit_op);
    eu_out.csr_alu_in.sel = v.csr_found &&
        (v.csr_owner_op.csrrwi | v.csr_owner_op.csrrsi | v.csr_owner_op.csrrci);
    eu_out.csr_alu_in.csr_op = v.csr_found ? v.csr_owner_op : init_csr_op;

    v.csr_result = v.csr_found ? eu_in.csr_alu_out.cdata : eu_in.csr.cdata;

    eu_out.div_in.rdata1 = v.div_issue[0] ? eu_in.int_issue[0].rdata1 :
        v.div_issue[1] ? eu_in.int_issue[1].rdata1 :
        v.div_issue[2] ? eu_in.int_issue[2].rdata1 : eu_in.int_issue[3].rdata1;
    eu_out.div_in.rdata2 = v.div_issue[0] ? eu_in.int_issue[0].rdata2 :
        v.div_issue[1] ? eu_in.int_issue[1].rdata2 :
        v.div_issue[2] ? eu_in.int_issue[2].rdata2 : eu_in.int_issue[3].rdata2;
    eu_out.div_in.div_op = rs_div_op(
        v.div_issue[0] ? eu_in.int_issue[0].unit_op : v.div_issue[1] ? eu_in.int_issue[1].unit_op :
            v.div_issue[2] ? eu_in.int_issue[2].unit_op : eu_in.int_issue[3].unit_op);
    eu_out.div_in.enable = v.div_issue[0] | v.div_issue[1] | v.div_issue[2] | v.div_issue[3];

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      v.eu_result_lane[l] = eu_result(
        v.int_issue[l],
        v.npc_lane[l],
        eu_in.alu_out[l].result,
        v.agu_result_lane[l],
        v.mul_result_lane[l],
        eu_in.div_out.result,
        v.bit_result_lane[l],
        eu_in.csr.cdata
      );
      v.eu_done_lane[l] = eu_done(v.int_issue[l], v.int_issue_valid[l], eu_in.div_out);
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      v.mem_lsu_op[p] = rs_lsu_op(eu_in.mem_issue[p].unit_op);
      v.mstore_data[p] = store_data(
        eu_in.mem_issue[p].rdata2,
        v.mem_lsu_op[p].lsu_sb,
        v.mem_lsu_op[p].lsu_sh,
        v.mem_lsu_op[p].lsu_sw
      );
    end

    if (!flush) begin

      if (r.div_pending_valid && eu_in.div_out.ready) begin
        if (r.div_pending.op.wren) begin
          v.cdb[0].valid = 1'b1;
          v.cdb[0].tag   = r.div_pending.pdest;
          v.cdb[0].data  = eu_in.div_out.result;
        end
        v.rob_wtag[0]             = r.div_pending.rob_tag;
        v.rob_wen[0]              = 1'b1;
        v.rob_wentry[0].done      = 1'b1;
        v.rob_wentry[0].result    = eu_in.div_out.result;
        v.rob_wentry[0].target    = '0;
        v.rob_wentry[0].branch    = 1'b0;
        v.rob_wentry[0].jump      = 1'b0;
        v.rob_wentry[0].exception = 1'b0;
        v.rob_wentry[0].ecause    = '0;
        v.rob_wentry[0].wdata     = '0;

      end else if (v.int_issue_valid[0] && v.eu_done_lane[0]) begin
        if (v.int_issue[0].op.wren) begin
          v.cdb[0].valid = 1'b1;
          v.cdb[0].tag   = v.int_issue[0].pdest;
          v.cdb[0].data  = v.eu_result_lane[0];
        end
        v.rob_wen[0] = 1'b1;
        v.rob_wentry[0].done = 1'b1;
        v.rob_wentry[0].target = v.agu_result_lane[0];
        v.rob_wentry[0].branch = v.int_issue[0].op.branch;
        v.rob_wentry[0].jump = v.int_issue[0].op.jal | v.int_issue[0].op.jalr |
            v.branch_taken_lane[0];
        v.rob_wentry[0].exception = v.int_issue[0].op.exception | v.int_issue[0].op.ecall |
            v.int_issue[0].op.ebreak | v.agu_exception_lane[0];
        v.rob_wentry[0].ecause = v.int_issue[0].op.exception ? except_illegal_instruction :
            v.int_issue[0].op.ecall ? except_env_call_user :
            v.int_issue[0].op.ebreak ? except_breakpoint : v.agu_ecause_lane[0];
        v.rob_wentry[0].result = (v.int_issue[0].op.exception | v.int_issue[0].op.ecall |
                                  v.int_issue[0].op.ebreak | v.agu_exception_lane[0]) ?
            v.agu_etval_lane[0] : v.eu_result_lane[0];
        v.rob_wentry[0].wdata = v.csr_result;
      end

      if (v.int_issue_valid[1] && v.eu_done_lane[1]) begin
        if (v.int_issue[1].op.wren) begin
          v.cdb[1].valid = 1'b1;
          v.cdb[1].tag   = v.int_issue[1].pdest;
          v.cdb[1].data  = v.eu_result_lane[1];
        end
        v.rob_wen[1] = 1'b1;
        v.rob_wentry[1].done = 1'b1;
        v.rob_wentry[1].target = v.agu_result_lane[1];
        v.rob_wentry[1].branch = v.int_issue[1].op.branch;
        v.rob_wentry[1].jump = v.int_issue[1].op.jal | v.int_issue[1].op.jalr |
            v.branch_taken_lane[1];
        v.rob_wentry[1].exception = v.int_issue[1].op.exception | v.int_issue[1].op.ecall |
            v.int_issue[1].op.ebreak | v.agu_exception_lane[1];
        v.rob_wentry[1].ecause = v.int_issue[1].op.exception ? except_illegal_instruction :
            v.int_issue[1].op.ecall ? except_env_call_user :
            v.int_issue[1].op.ebreak ? except_breakpoint : v.agu_ecause_lane[1];
        v.rob_wentry[1].result = (v.int_issue[1].op.exception | v.int_issue[1].op.ecall |
                                  v.int_issue[1].op.ebreak | v.agu_exception_lane[1]) ?
            v.agu_etval_lane[1] : v.eu_result_lane[1];
        v.rob_wentry[1].wdata = v.csr_result;
      end

      for (int l = 2; l < ISSUE_WIDTH; l++) begin
        if (v.int_issue_valid[l] && v.eu_done_lane[l]) begin
          if (v.int_issue[l].op.wren) begin
            v.cdb[l].valid = 1'b1;
            v.cdb[l].tag   = v.int_issue[l].pdest;
            v.cdb[l].data  = v.eu_result_lane[l];
          end
          v.rob_wen[l] = 1'b1;
          v.rob_wentry[l].done = 1'b1;
          v.rob_wentry[l].target = v.agu_result_lane[l];
          v.rob_wentry[l].branch = v.int_issue[l].op.branch;
          v.rob_wentry[l].jump = v.int_issue[l].op.jal | v.int_issue[l].op.jalr |
              v.branch_taken_lane[l];
          v.rob_wentry[l].exception = v.int_issue[l].op.exception | v.int_issue[l].op.ecall |
              v.int_issue[l].op.ebreak | v.agu_exception_lane[l];
          v.rob_wentry[l].ecause = v.int_issue[l].op.exception ? except_illegal_instruction :
              v.int_issue[l].op.ecall ? except_env_call_user :
              v.int_issue[l].op.ebreak ? except_breakpoint : v.agu_ecause_lane[l];
          v.rob_wentry[l].result = (v.int_issue[l].op.exception | v.int_issue[l].op.ecall |
                                    v.int_issue[l].op.ebreak | v.agu_exception_lane[l]) ?
              v.agu_etval_lane[l] : v.eu_result_lane[l];
          v.rob_wentry[l].wdata = v.csr_result;
        end
      end

      for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
        if (eu_in.mem_issue_valid[p] && eu_in.mem_issue[p].op.store) begin
          v.rob_wtag_store[p]              = eu_in.mem_issue[p].rob_tag;
          v.rob_wen_store[p]               = 1'b1;
          v.rob_wentry_store[p].done       = 1'b1;
          v.rob_wentry_store[p].target     = eu_in.agu_out[AGU_BRANCH_COUNT+p].address;
          v.rob_wentry_store[p].wdata      = v.mstore_data[p];
          v.rob_wentry_store[p].store_strb = eu_in.agu_out[AGU_BRANCH_COUNT+p].byteenable;
          v.rob_wentry_store[p].exception  = eu_in.agu_out[AGU_BRANCH_COUNT+p].exception;
          v.rob_wentry_store[p].ecause     = eu_in.agu_out[AGU_BRANCH_COUNT+p].ecause;
          v.rob_wentry_store[p].result     = eu_in.agu_out[AGU_BRANCH_COUNT+p].etval;
        end
      end

    end

    rin = v;

    for (int l = 0; l < ISSUE_WIDTH; l++) begin
      eu_out.cdb[l]        = r.cdb[l];
      eu_out.rob_wtag[l]   = r.rob_wtag[l];
      eu_out.rob_wentry[l] = r.rob_wentry[l];
      eu_out.rob_wen[l]    = r.rob_wen[l];
    end
    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      eu_out.rob_wtag_store[p]   = r.rob_wtag_store[p];
      eu_out.rob_wentry_store[p] = r.rob_wentry_store[p];
      eu_out.rob_wen_store[p]    = r.rob_wen_store[p];
    end
    eu_out.div_busy = r.div_pending_valid;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_eu_reg;
    end else begin
      r <= rin;
    end
  end

endmodule
