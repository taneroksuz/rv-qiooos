import configure::*;
import constants::*;
import wires::*;
import functions::*;

module decode (
  input  logic           reset,
  input  logic           clock,
  input  logic           flush,
  input  logic           stall,
  input  decode_in_type  decode_in,
  output decode_out_type decode_out
);
  timeunit 1ns; timeprecision 1ps;

  decode_reg_type r, rin;
  decode_reg_type v;

  always_comb begin

    v = r;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.instr[i].pc    = decode_in.ready[i] ? decode_in.pc[i] : 32'hFFFFFFFF;
      v.instr[i].instr = decode_in.ready[i] ? decode_in.instr[i] : 0;
      v.instr[i].op    = init_operation;
    end

    if (stall == 1) begin
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        v.instr[i] = r.instr[i];
      end
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.instr[i].npc = v.instr[i].pc + ((&v.instr[i].instr[1:0]) ? 4 : 2);

      v.instr[i].waddr  = v.instr[i].instr[11:7];
      v.instr[i].raddr1 = v.instr[i].instr[19:15];
      v.instr[i].raddr2 = v.instr[i].instr[24:20];
      v.instr[i].raddr3 = v.instr[i].instr[31:27];
      v.instr[i].caddr  = v.instr[i].instr[31:20];

      decode_out.base_in[i].instr = v.instr[i].instr;

      v.instr[i].instr_str   = decode_in.base_out[i].instr_str;
      v.instr[i].imm         = decode_in.base_out[i].imm;
      v.instr[i].op.wren     = decode_in.base_out[i].wren;
      v.instr[i].op.rden1    = decode_in.base_out[i].rden1;
      v.instr[i].op.rden2    = decode_in.base_out[i].rden2;
      v.instr[i].op.cwren    = decode_in.base_out[i].cwren;
      v.instr[i].op.crden    = decode_in.base_out[i].crden;
      v.instr[i].op.alunit   = decode_in.base_out[i].alunit;
      v.instr[i].op.auipc    = decode_in.base_out[i].auipc;
      v.instr[i].op.lui      = decode_in.base_out[i].lui;
      v.instr[i].op.jal      = decode_in.base_out[i].jal;
      v.instr[i].op.jalr     = decode_in.base_out[i].jalr;
      v.instr[i].op.branch   = decode_in.base_out[i].branch;
      v.instr[i].op.load     = decode_in.base_out[i].load;
      v.instr[i].op.store    = decode_in.base_out[i].store;
      v.instr[i].op.nop      = decode_in.base_out[i].nop;
      v.instr[i].op.csreg    = decode_in.base_out[i].csreg;
      v.instr[i].op.division = decode_in.base_out[i].division;
      v.instr[i].op.mult     = decode_in.base_out[i].mult;
      v.instr[i].op.bitm     = decode_in.base_out[i].bitm;
      v.instr[i].op.fence    = decode_in.base_out[i].fence;
      v.instr[i].op.ecall    = decode_in.base_out[i].ecall;
      v.instr[i].op.ebreak   = decode_in.base_out[i].ebreak;
      v.instr[i].op.mret     = decode_in.base_out[i].mret;
      v.instr[i].op.wfi      = decode_in.base_out[i].wfi;
      v.instr[i].op.valid    = decode_in.base_out[i].valid;
      v.instr[i].alu_op      = decode_in.base_out[i].alu_op;
      v.instr[i].bcu_op      = decode_in.base_out[i].bcu_op;
      v.instr[i].lsu_op      = decode_in.base_out[i].lsu_op;
      v.instr[i].csr_op      = decode_in.base_out[i].csr_op;
      v.instr[i].div_op      = decode_in.base_out[i].div_op;
      v.instr[i].mul_op      = decode_in.base_out[i].mul_op;
      v.instr[i].bit_op      = decode_in.base_out[i].bit_op;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      decode_out.compress_in[i].instr = v.instr[i].instr;

      if (decode_in.compress_out[i].valid == 1) begin
        v.instr[i].instr_str = decode_in.compress_out[i].instr_str;
        v.instr[i].imm       = decode_in.compress_out[i].imm;
        v.instr[i].waddr     = decode_in.compress_out[i].waddr;
        v.instr[i].raddr1    = decode_in.compress_out[i].raddr1;
        v.instr[i].raddr2    = decode_in.compress_out[i].raddr2;
        v.instr[i].op.wren   = decode_in.compress_out[i].wren;
        v.instr[i].op.rden1  = decode_in.compress_out[i].rden1;
        v.instr[i].op.rden2  = decode_in.compress_out[i].rden2;
        v.instr[i].op.alunit = decode_in.compress_out[i].alunit;
        v.instr[i].op.lui    = decode_in.compress_out[i].lui;
        v.instr[i].op.jal    = decode_in.compress_out[i].jal;
        v.instr[i].op.jalr   = decode_in.compress_out[i].jalr;
        v.instr[i].op.branch = decode_in.compress_out[i].branch;
        v.instr[i].op.load   = decode_in.compress_out[i].load;
        v.instr[i].op.store  = decode_in.compress_out[i].store;
        v.instr[i].op.nop    = decode_in.compress_out[i].nop;
        v.instr[i].op.ebreak = decode_in.compress_out[i].ebreak;
        v.instr[i].op.valid  = decode_in.compress_out[i].valid;
        v.instr[i].alu_op    = decode_in.compress_out[i].alu_op;
        v.instr[i].bcu_op    = decode_in.compress_out[i].bcu_op;
        v.instr[i].lsu_op    = decode_in.compress_out[i].lsu_op;
      end
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      if (decode_in.ready[i] == 1) begin
        if (v.instr[i].op.valid == 0) begin
          v.instr[i].op.exception = 1;
          v.instr[i].op.valid     = 1;
        end
      end
    end

    if (flush == 1) begin
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        v.instr[i] = init_instruction;
      end
    end

    v.squash[0] = 1'b0;
    for (int i = 1; i < ISSUE_WIDTH; i++) begin
      v.squash[i] = v.squash[i-1] | decode_in.btac_out.pred[i-1].taken;
    end

    rin = v;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      decode_out.instr[i] = r.instr[i];
      if (v.squash[i]) begin
        decode_out.instr[i].op = init_operation;
      end
      decode_out.instr[i].pred.taken = decode_in.btac_out.pred[i].taken;
      decode_out.instr[i].pred.taddr = decode_in.btac_out.pred[i].taddr;
      decode_out.instr[i].pred.tsat  = decode_in.btac_out.pred[i].tsat;
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_decode_reg;
    end else begin
      r <= rin;
    end
  end

endmodule
