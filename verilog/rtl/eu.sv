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
    cdb_type [3:0]                 cdb;
    logic [3:0][ROB_ADDR_BITS-1:0] rob_wtag;
    rob_entry_type [3:0]           rob_wentry;
    logic [3:0]                    rob_wen;
    logic [1:0][ROB_ADDR_BITS-1:0] rob_wtag_store;
    rob_entry_type [1:0]           rob_wentry_store;
    logic [1:0]                    rob_wen_store;
    rs_entry_type                  div_pending;
    logic [0:0]                    div_pending_valid;
    rs_entry_type                  clmul_pending;
    logic [0:0]                    clmul_pending_valid;
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
      clmul_pending      : init_rs_entry,
      clmul_pending_valid: 0
  };

  eu_reg_type r, rin;
  eu_reg_type v;

  rs_entry_type int_issue      [0:3];
  logic         int_issue_valid[0:3];

  logic [31:0] agu_result_lane   [0:3];
  logic        agu_exception_lane[0:3];
  logic [ 7:0] agu_ecause_lane   [0:3];
  logic [31:0] agu_etval_lane    [0:3];
  logic [31:0] mul_result_lane   [0:3];
  logic [31:0] bit_result_lane   [0:3];
  logic [31:0] csr_result_lane   [0:3];
  logic        branch_taken_lane [0:3];

  logic [31:0] eu_result_lane[0:3];
  logic        eu_done_lane  [0:3];

  logic agu_need [0:3];
  int   agu_owner[0:1];
  logic agu_found[0:1];

  int   bcu_owner[0:1];
  logic bcu_found[0:1];

  int   mul_owner[0:1];
  logic mul_found[0:1];

  int   bitalu_owner[0:1];
  logic bitalu_found[0:1];

  int          csr_owner;
  logic        csr_found;
  logic [31:0] mstore_data[0:1];

  logic div_issue  [0:3];
  logic clmul_issue[0:3];

  always_comb begin

    v = r;

    for (int l = 0; l < 4; l++) begin
      v.cdb[l]        = init_cdb;
      v.rob_wtag[l]   = eu_in.int_issue[l].rob_tag;
      v.rob_wentry[l] = init_rob_entry;
      v.rob_wen[l]    = 1'b0;
    end
    for (int l = 0; l < 2; l++) begin
      v.rob_wtag_store[l]   = eu_in.mem_issue[l].rob_tag;
      v.rob_wentry_store[l] = init_rob_entry;
      v.rob_wen_store[l]    = 1'b0;
    end

    for (int l = 0; l < 4; l++) begin
      int_issue[l]       = eu_in.int_issue[l];
      int_issue_valid[l] = eu_in.int_issue_valid[l];
    end

    div_issue[0] = eu_in.int_issue_valid[0] & eu_in.int_issue[0].op.division & ~r.div_pending_valid;
    for (int l = 1; l < 4; l++) begin
      div_issue[l] = eu_in.int_issue_valid[l] &
          eu_in.int_issue[l].op.division & ~r.div_pending_valid;
      for (int j = 0; j < l; j++) begin
        div_issue[l] = div_issue[l] & ~div_issue[j];
      end
    end

    clmul_issue[0] = eu_in.int_issue_valid[0] & eu_in.int_issue[0].op.bitc & ~r.clmul_pending_valid;
    for (int l = 1; l < 4; l++) begin
      clmul_issue[l] = eu_in.int_issue_valid[l] &
          eu_in.int_issue[l].op.bitc & ~r.clmul_pending_valid;
      for (int j = 0; j < l; j++) begin
        clmul_issue[l] = clmul_issue[l] & ~clmul_issue[j];
      end
    end

    if (flush) begin
      v.div_pending_valid   = 1'b0;
      v.clmul_pending_valid = 1'b0;
    end else begin
      if (eu_in.div_out.ready) begin
        v.div_pending_valid = 1'b0;
      end else begin
        for (int l = 0; l < 4; l++) begin
          if (div_issue[l]) begin
            v.div_pending       = eu_in.int_issue[l];
            v.div_pending_valid = 1'b1;
          end
        end
      end

      if (eu_in.bit_clmul_out.ready) begin
        v.clmul_pending_valid = 1'b0;
      end else begin
        for (int l = 0; l < 4; l++) begin
          if (clmul_issue[l]) begin
            v.clmul_pending       = eu_in.int_issue[l];
            v.clmul_pending_valid = 1'b1;
          end
        end
      end
    end

    for (int l = 0; l < 4; l++) begin
      eu_out.alu_in[l].rdata1 = int_issue[l].rdata1;
      eu_out.alu_in[l].rdata2 = int_issue[l].rdata2;
      eu_out.alu_in[l].imm    = int_issue[l].imm;
      eu_out.alu_in[l].sel    = int_issue[l].op.rden2;
      eu_out.alu_in[l].alu_op = int_issue[l].alu_op;
    end

    for (int l = 0; l < 2; l++) begin
      eu_out.agu_in[2+l].rdata1 = eu_in.mem_issue[l].rdata1;
      eu_out.agu_in[2+l].imm    = eu_in.mem_issue[l].imm;
      eu_out.agu_in[2+l].pc     = eu_in.mem_issue[l].pc;
      eu_out.agu_in[2+l].auipc  = 1'b0;
      eu_out.agu_in[2+l].jal    = 1'b0;
      eu_out.agu_in[2+l].jalr   = 1'b0;
      eu_out.agu_in[2+l].branch = 1'b0;
      eu_out.agu_in[2+l].load   = eu_in.mem_issue[l].op.load;
      eu_out.agu_in[2+l].store  = eu_in.mem_issue[l].op.store;
      eu_out.agu_in[2+l].lsu_op = eu_in.mem_issue[l].lsu_op;
    end

    agu_found[0] = 1'b0;
    agu_found[1] = 1'b0;
    agu_owner[0] = 0;
    agu_owner[1] = 0;

    for (int l = 0; l < 4; l++) begin
      agu_need[l] = int_issue_valid[l] && (int_issue[l].op.auipc || int_issue[l].op.jal ||
                                           int_issue[l].op.jalr || int_issue[l].op.branch);
      if (agu_need[l]) begin
        if (!agu_found[0]) begin
          agu_owner[0] = l;
          agu_found[0] = 1'b1;
        end else if (!agu_found[1]) begin
          agu_owner[1] = l;
          agu_found[1] = 1'b1;
        end
      end
    end

    for (int p = 0; p < 2; p++) begin
      eu_out.agu_in[p].rdata1 = agu_found[p] ? int_issue[agu_owner[p]].rdata1 : 32'h0;
      eu_out.agu_in[p].imm    = agu_found[p] ? int_issue[agu_owner[p]].imm : 32'h0;
      eu_out.agu_in[p].pc     = agu_found[p] ? int_issue[agu_owner[p]].pc : 32'h0;
      eu_out.agu_in[p].auipc  = agu_found[p] ? int_issue[agu_owner[p]].op.auipc : 1'b0;
      eu_out.agu_in[p].jal    = agu_found[p] ? int_issue[agu_owner[p]].op.jal : 1'b0;
      eu_out.agu_in[p].jalr   = agu_found[p] ? int_issue[agu_owner[p]].op.jalr : 1'b0;
      eu_out.agu_in[p].branch = agu_found[p] ? int_issue[agu_owner[p]].op.branch : 1'b0;
      eu_out.agu_in[p].load   = 1'b0;
      eu_out.agu_in[p].store  = 1'b0;
      eu_out.agu_in[p].lsu_op = init_lsu_op;
    end

    for (int l = 0; l < 4; l++) begin
      if (agu_found[0] && agu_owner[0] == l) begin
        agu_result_lane[l]    = eu_in.agu_out[0].address;
        agu_exception_lane[l] = eu_in.agu_out[0].exception;
        agu_ecause_lane[l]    = eu_in.agu_out[0].ecause;
        agu_etval_lane[l]     = eu_in.agu_out[0].etval;
      end else if (agu_found[1] && agu_owner[1] == l) begin
        agu_result_lane[l]    = eu_in.agu_out[1].address;
        agu_exception_lane[l] = eu_in.agu_out[1].exception;
        agu_ecause_lane[l]    = eu_in.agu_out[1].ecause;
        agu_etval_lane[l]     = eu_in.agu_out[1].etval;
      end else begin
        agu_result_lane[l]    = int_issue[l].npc;
        agu_exception_lane[l] = 1'b0;
        agu_ecause_lane[l]    = '0;
        agu_etval_lane[l]     = 32'h0;
      end
    end

    begin
      bcu_found[0] = 1'b0;
      bcu_found[1] = 1'b0;
      bcu_owner[0] = 0;
      bcu_owner[1] = 0;

      for (int l = 0; l < 4; l++) begin
        if (int_issue_valid[l] && int_issue[l].op.branch) begin
          if (!bcu_found[0]) begin
            bcu_owner[0] = l;
            bcu_found[0] = 1'b1;
          end else if (!bcu_found[1]) begin
            bcu_owner[1] = l;
            bcu_found[1] = 1'b1;
          end
        end
      end

      for (int p = 0; p < 2; p++) begin
        eu_out.bcu_in[p].rdata1 = bcu_found[p] ? int_issue[bcu_owner[p]].rdata1 : 32'h0;
        eu_out.bcu_in[p].rdata2 = bcu_found[p] ? int_issue[bcu_owner[p]].rdata2 : 32'h0;
        eu_out.bcu_in[p].enable = bcu_found[p];
        eu_out.bcu_in[p].bcu_op = bcu_found[p] ? int_issue[bcu_owner[p]].bcu_op : init_bcu_op;
      end

      for (int l = 0; l < 4; l++) begin
        if (bcu_found[0] && bcu_owner[0] == l) begin
          branch_taken_lane[l] = int_issue[l].op.branch & eu_in.bcu_out[0].branch;
        end else if (bcu_found[1] && bcu_owner[1] == l) begin
          branch_taken_lane[l] = int_issue[l].op.branch & eu_in.bcu_out[1].branch;
        end else begin
          branch_taken_lane[l] = 1'b0;
        end
      end
    end

    begin
      mul_found[0] = 1'b0;
      mul_found[1] = 1'b0;
      mul_owner[0] = 0;
      mul_owner[1] = 0;

      for (int l = 0; l < 4; l++) begin
        if (int_issue_valid[l] && int_issue[l].op.mult) begin
          if (!mul_found[0]) begin
            mul_owner[0] = l;
            mul_found[0] = 1'b1;
          end else if (!mul_found[1]) begin
            mul_owner[1] = l;
            mul_found[1] = 1'b1;
          end
        end
      end

      for (int p = 0; p < 2; p++) begin
        eu_out.mul_in[p].rdata1 = mul_found[p] ? int_issue[mul_owner[p]].rdata1 : 32'h0;
        eu_out.mul_in[p].rdata2 = mul_found[p] ? int_issue[mul_owner[p]].rdata2 : 32'h0;
        eu_out.mul_in[p].mul_op = mul_found[p] ? int_issue[mul_owner[p]].mul_op : init_mul_op;
      end

      for (int l = 0; l < 4; l++) begin
        if (mul_found[0] && mul_owner[0] == l) begin
          mul_result_lane[l] = eu_in.mul_out[0].result;
        end else if (mul_found[1] && mul_owner[1] == l) begin
          mul_result_lane[l] = eu_in.mul_out[1].result;
        end else begin
          mul_result_lane[l] = 32'h0;
        end
      end
    end

    begin
      bitalu_found[0] = 1'b0;
      bitalu_found[1] = 1'b0;
      bitalu_owner[0] = 0;
      bitalu_owner[1] = 0;

      for (int l = 0; l < 4; l++) begin
        if (int_issue_valid[l] && int_issue[l].op.bitm) begin
          if (!bitalu_found[0]) begin
            bitalu_owner[0] = l;
            bitalu_found[0] = 1'b1;
          end else if (!bitalu_found[1]) begin
            bitalu_owner[1] = l;
            bitalu_found[1] = 1'b1;
          end
        end
      end

      for (int p = 0; p < 2; p++) begin
        eu_out.bit_alu_in[p].rdata1 = bitalu_found[p] ? int_issue[bitalu_owner[p]].rdata1 : 32'h0;
        eu_out.bit_alu_in[p].rdata2 = bitalu_found[p] ? int_issue[bitalu_owner[p]].rdata2 : 32'h0;
        eu_out.bit_alu_in[p].imm = bitalu_found[p] ? int_issue[bitalu_owner[p]].imm : 32'h0;
        eu_out.bit_alu_in[p].sel = bitalu_found[p] ? int_issue[bitalu_owner[p]].op.rden2 : 1'b0;
        eu_out.bit_alu_in[p].bit_op = bitalu_found[p] ? int_issue[bitalu_owner[p]].bit_op :
            init_bit_op;
      end

      for (int l = 0; l < 4; l++) begin
        if (bitalu_found[0] && bitalu_owner[0] == l) begin
          bit_result_lane[l] = eu_in.bit_alu_out[0].result;
        end else if (bitalu_found[1] && bitalu_owner[1] == l) begin
          bit_result_lane[l] = eu_in.bit_alu_out[1].result;
        end else begin
          bit_result_lane[l] = 32'h0;
        end
      end
    end

    begin
      csr_found = 1'b0;
      csr_owner = 0;

      for (int l = 0; l < 4; l++) begin
        if (int_issue_valid[l] && int_issue[l].op.csreg && !csr_found) begin
          csr_owner = l;
          csr_found = 1'b1;
        end
      end

      eu_out.csr_alu_in[0].cdata = eu_in.csr.cdata;
      eu_out.csr_alu_in[0].rdata1 = csr_found ? int_issue[csr_owner].rdata1 : 32'h0;
      eu_out.csr_alu_in[0].imm = csr_found ? int_issue[csr_owner].imm : 32'h0;
      eu_out.csr_alu_in[0].sel = csr_found &&
          (int_issue[csr_owner].csr_op.csrrwi | int_issue[csr_owner].csr_op.csrrsi |
           int_issue[csr_owner].csr_op.csrrci);
      eu_out.csr_alu_in[0].csr_op = csr_found ? int_issue[csr_owner].csr_op : init_csr_op;

      eu_out.csr_alu_in[1].cdata  = eu_in.csr.cdata;
      eu_out.csr_alu_in[1].rdata1 = 32'h0;
      eu_out.csr_alu_in[1].imm    = 32'h0;
      eu_out.csr_alu_in[1].sel    = 1'b0;
      eu_out.csr_alu_in[1].csr_op = init_csr_op;

      for (int l = 0; l < 4; l++) begin
        if (csr_found && csr_owner == l) begin
          csr_result_lane[l] = eu_in.csr_alu_out[0].cdata;
        end else begin
          csr_result_lane[l] = eu_in.csr.cdata;
        end
      end
    end

    eu_out.div_in.rdata1 = div_issue[0] ? eu_in.int_issue[0].rdata1 :
        div_issue[1] ? eu_in.int_issue[1].rdata1 :
        div_issue[2] ? eu_in.int_issue[2].rdata1 : eu_in.int_issue[3].rdata1;
    eu_out.div_in.rdata2 = div_issue[0] ? eu_in.int_issue[0].rdata2 :
        div_issue[1] ? eu_in.int_issue[1].rdata2 :
        div_issue[2] ? eu_in.int_issue[2].rdata2 : eu_in.int_issue[3].rdata2;
    eu_out.div_in.div_op = div_issue[0] ? eu_in.int_issue[0].div_op :
        div_issue[1] ? eu_in.int_issue[1].div_op :
        div_issue[2] ? eu_in.int_issue[2].div_op : eu_in.int_issue[3].div_op;
    eu_out.div_in.enable = div_issue[0] | div_issue[1] | div_issue[2] | div_issue[3];

    eu_out.bit_clmul_in.rdata1 = clmul_issue[0] ? eu_in.int_issue[0].rdata1 :
        clmul_issue[1] ? eu_in.int_issue[1].rdata1 :
        clmul_issue[2] ? eu_in.int_issue[2].rdata1 : eu_in.int_issue[3].rdata1;
    eu_out.bit_clmul_in.rdata2 = clmul_issue[0] ? eu_in.int_issue[0].rdata2 :
        clmul_issue[1] ? eu_in.int_issue[1].rdata2 :
        clmul_issue[2] ? eu_in.int_issue[2].rdata2 : eu_in.int_issue[3].rdata2;
    eu_out.bit_clmul_in.enable = clmul_issue[0] | clmul_issue[1] | clmul_issue[2] | clmul_issue[3];
    eu_out.bit_clmul_in.op = clmul_issue[0] ? eu_in.int_issue[0].bit_op.bit_zbc :
        clmul_issue[1] ? eu_in.int_issue[1].bit_op.bit_zbc :
        clmul_issue[2] ? eu_in.int_issue[2].bit_op.bit_zbc : eu_in.int_issue[3].bit_op.bit_zbc;

    for (int l = 0; l < 4; l++) begin
      eu_result_lane[l] = eu_result(
        int_issue[l],
        eu_in.alu_out[l].result,
        agu_result_lane[l],
        mul_result_lane[l],
        eu_in.div_out.result,
        bit_result_lane[l],
        eu_in.csr.cdata,
        eu_in.bit_clmul_out.result
      );
      eu_done_lane[l] =
          eu_done(int_issue[l], int_issue_valid[l], eu_in.div_out, eu_in.bit_clmul_out);
    end

    for (int p = 0; p < 2; p++) begin
      mstore_data[p] = store_data(
        eu_in.mem_issue[p].rdata2,
        eu_in.mem_issue[p].lsu_op.lsu_sb,
        eu_in.mem_issue[p].lsu_op.lsu_sh,
        eu_in.mem_issue[p].lsu_op.lsu_sw
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
        v.rob_wentry[0].npc       = '0;
        v.rob_wentry[0].branch    = 1'b0;
        v.rob_wentry[0].jump      = 1'b0;
        v.rob_wentry[0].exception = 1'b0;
        v.rob_wentry[0].ecause    = '0;
        v.rob_wentry[0].etval     = '0;
        v.rob_wentry[0].cwdata    = '0;

      end else if (int_issue_valid[0] && eu_done_lane[0]) begin
        if (int_issue[0].op.wren) begin
          v.cdb[0].valid = 1'b1;
          v.cdb[0].tag   = int_issue[0].pdest;
          v.cdb[0].data  = eu_result_lane[0];
        end
        v.rob_wen[0] = 1'b1;
        v.rob_wentry[0].done = 1'b1;
        v.rob_wentry[0].result = eu_result_lane[0];
        v.rob_wentry[0].npc = agu_result_lane[0];
        v.rob_wentry[0].branch = int_issue[0].op.branch;
        v.rob_wentry[0].jump = int_issue[0].op.jal | int_issue[0].op.jalr | branch_taken_lane[0];
        v.rob_wentry[0].exception = int_issue[0].op.ecall | int_issue[0].op.ebreak |
            agu_exception_lane[0];
        v.rob_wentry[0].ecause = int_issue[0].op.ecall ? except_env_call_user :
            int_issue[0].op.ebreak ? except_breakpoint : agu_ecause_lane[0];
        v.rob_wentry[0].etval = agu_etval_lane[0];
        v.rob_wentry[0].cwdata = csr_result_lane[0];
      end

      if (r.clmul_pending_valid && eu_in.bit_clmul_out.ready) begin
        if (r.clmul_pending.op.wren) begin
          v.cdb[1].valid = 1'b1;
          v.cdb[1].tag   = r.clmul_pending.pdest;
          v.cdb[1].data  = eu_in.bit_clmul_out.result;
        end
        v.rob_wtag[1]             = r.clmul_pending.rob_tag;
        v.rob_wen[1]              = 1'b1;
        v.rob_wentry[1].done      = 1'b1;
        v.rob_wentry[1].result    = eu_in.bit_clmul_out.result;
        v.rob_wentry[1].npc       = '0;
        v.rob_wentry[1].branch    = 1'b0;
        v.rob_wentry[1].jump      = 1'b0;
        v.rob_wentry[1].exception = 1'b0;
        v.rob_wentry[1].ecause    = '0;
        v.rob_wentry[1].etval     = '0;
        v.rob_wentry[1].cwdata    = '0;

      end else if (int_issue_valid[1] && eu_done_lane[1]) begin
        if (int_issue[1].op.wren) begin
          v.cdb[1].valid = 1'b1;
          v.cdb[1].tag   = int_issue[1].pdest;
          v.cdb[1].data  = eu_result_lane[1];
        end
        v.rob_wen[1] = 1'b1;
        v.rob_wentry[1].done = 1'b1;
        v.rob_wentry[1].result = eu_result_lane[1];
        v.rob_wentry[1].npc = agu_result_lane[1];
        v.rob_wentry[1].branch = int_issue[1].op.branch;
        v.rob_wentry[1].jump = int_issue[1].op.jal | int_issue[1].op.jalr | branch_taken_lane[1];
        v.rob_wentry[1].exception = int_issue[1].op.ecall | int_issue[1].op.ebreak |
            agu_exception_lane[1];
        v.rob_wentry[1].ecause = int_issue[1].op.ecall ? except_env_call_user :
            int_issue[1].op.ebreak ? except_breakpoint : agu_ecause_lane[1];
        v.rob_wentry[1].etval = agu_etval_lane[1];
        v.rob_wentry[1].cwdata = csr_result_lane[1];
      end

      for (int l = 2; l < 4; l++) begin
        if (int_issue_valid[l] && eu_done_lane[l]) begin
          if (int_issue[l].op.wren) begin
            v.cdb[l].valid = 1'b1;
            v.cdb[l].tag   = int_issue[l].pdest;
            v.cdb[l].data  = eu_result_lane[l];
          end
          v.rob_wen[l] = 1'b1;
          v.rob_wentry[l].done = 1'b1;
          v.rob_wentry[l].result = eu_result_lane[l];
          v.rob_wentry[l].npc = agu_result_lane[l];
          v.rob_wentry[l].branch = int_issue[l].op.branch;
          v.rob_wentry[l].jump = int_issue[l].op.jal | int_issue[l].op.jalr | branch_taken_lane[l];
          v.rob_wentry[l].exception = int_issue[l].op.ecall | int_issue[l].op.ebreak |
              agu_exception_lane[l];
          v.rob_wentry[l].ecause = int_issue[l].op.ecall ? except_env_call_user :
              int_issue[l].op.ebreak ? except_breakpoint : agu_ecause_lane[l];
          v.rob_wentry[l].etval = agu_etval_lane[l];
          v.rob_wentry[l].cwdata = csr_result_lane[l];
        end
      end

      for (int p = 0; p < 2; p++) begin
        if (eu_in.mem_issue_valid[p] && eu_in.mem_issue[p].op.store) begin
          v.rob_wtag_store[p]              = eu_in.mem_issue[p].rob_tag;
          v.rob_wen_store[p]               = 1'b1;
          v.rob_wentry_store[p].done       = 1'b1;
          v.rob_wentry_store[p].store_addr = eu_in.agu_out[2+p].address;
          v.rob_wentry_store[p].store_data = mstore_data[p];
          v.rob_wentry_store[p].store_strb = eu_in.agu_out[2+p].byteenable;
          v.rob_wentry_store[p].exception  = eu_in.agu_out[2+p].exception;
          v.rob_wentry_store[p].ecause     = eu_in.agu_out[2+p].ecause;
          v.rob_wentry_store[p].etval      = eu_in.agu_out[2+p].etval;
        end
      end

    end

    rin = v;

    for (int l = 0; l < 4; l++) begin
      eu_out.cdb[l]        = r.cdb[l];
      eu_out.rob_wtag[l]   = r.rob_wtag[l];
      eu_out.rob_wentry[l] = r.rob_wentry[l];
      eu_out.rob_wen[l]    = r.rob_wen[l];
    end
    for (int p = 0; p < 2; p++) begin
      eu_out.rob_wtag_store[p]   = r.rob_wtag_store[p];
      eu_out.rob_wentry_store[p] = r.rob_wentry_store[p];
      eu_out.rob_wen_store[p]    = r.rob_wen_store[p];
    end
    eu_out.div_busy   = r.div_pending_valid;
    eu_out.clmul_busy = r.clmul_pending_valid;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_eu_reg;
    end else begin
      r <= rin;
    end
  end

endmodule
