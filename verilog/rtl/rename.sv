import configure::*;
import constants::*;
import wires::*;
import functions::*;
module rename (
  input  logic           flush,
  input  rename_in_type  rename_in,
  output rename_out_type rename_out
);
  timeunit 1ns; timeprecision 1ps;

  logic    rob_ok;
  logic    stall;
  cdb_type cdb_load_any;

  logic                     is_mem      [ISSUE_WIDTH];
  logic                     need_fl     [ISSUE_WIDTH];
  logic                     rs_ok       [ISSUE_WIDTH];
  logic                     fl_ok       [ISSUE_WIDTH];
  logic                     can_dispatch[ISSUE_WIDTH];
  logic                     dispatch    [ISSUE_WIDTH];
  logic [PRF_ADDR_BITS-1:0] pdest_arr   [ISSUE_WIDTH];

  logic [PRF_ADDR_BITS-1:0] fl_tag_arr[ISSUE_WIDTH];
  logic [              0:0] fl_ok_arr [ISSUE_WIDTH];

  logic [2:0] fl_count;

  logic        src_rdy [2*ISSUE_WIDTH];
  logic [31:0] src_data[2*ISSUE_WIDTH];

  logic [PRF_ADDR_BITS-1:0] src_tag;
  logic                     src_pv;
  logic [    ISSUE_WIDTH:0] src_hit;

  rs_entry_type  e;
  rob_entry_type re;

  always_comb begin
    rename_out   = '0;
    cdb_load_any = rename_in.cdb_load[0].valid ? rename_in.cdb_load[0] : rename_in.cdb_load[1];

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      fl_tag_arr[i] = rename_in.fl.alloc_tag[i];
      fl_ok_arr[i]  = rename_in.fl.alloc_ok[i];
    end

    rob_ok = rename_in.rob_alloc_ok[0];

    fl_count = 0;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      is_mem[i]  = rename_in.instr_valid[i] && (rename_in.instr[i].op.load || rename_in.instr[i].op.store);
      need_fl[i] = rename_in.instr_valid[i] && rename_in.instr[i].op.wren && (rename_in.instr[i].waddr != 5'h0);

      if (is_mem[i]) begin
        rs_ok[i] = rename_in.rs_mem_alloc_ok[i];
      end
      else begin
        rs_ok[i] = rename_in.rs_int_alloc_ok[i];
      end

      if (need_fl[i]) begin
        fl_ok[i]     = fl_ok_arr[ISSUE_ADDR_BITS'(fl_count)];
        pdest_arr[i] = fl_tag_arr[ISSUE_ADDR_BITS'(fl_count)];
        fl_count     = fl_count + 1;
      end
      else begin
        fl_ok[i]     = 1'b1;
        pdest_arr[i] = PRF_ADDR_BITS'(0);
      end
    end

    can_dispatch[0] = rename_in.instr_valid[0] && rob_ok && rs_ok[0] && fl_ok[0] && !flush;
    for (int i = 1; i < ISSUE_WIDTH; i++) begin
      can_dispatch[i] = rename_in.instr_valid[i] && can_dispatch[i-1] && rob_ok && rs_ok[i] && fl_ok[i] && !flush;
    end

    stall = 1'b0;
    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      if (rename_in.instr_valid[i] && !can_dispatch[i]) begin
        stall = 1'b1;
      end
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      dispatch[i] = stall ? 1'b0 : can_dispatch[i];
    end

    rename_out.stall = stall;

    for (int j = 0; j < 2 * ISSUE_WIDTH; j++) begin
      src_tag = rename_in.rat.psrc[j];
      src_pv  = rename_in.rat.psrc_valid[j] && rename_in.prf.rvalid[j];

      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        src_hit[k] = rename_in.cdb[k].valid && (rename_in.cdb[k].tag == src_tag);
      end
      src_hit[ISSUE_WIDTH] = cdb_load_any.valid && (cdb_load_any.tag == src_tag);

      src_rdy[j]  = src_pv || (|src_hit);
      src_data[j] = src_pv ? rename_in.prf.rdata[j] : 32'h0;
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (src_hit[k]) src_data[j] = rename_in.cdb[k].data;
      end
      if (src_hit[ISSUE_WIDTH]) src_data[j] = cdb_load_any.data;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      e = '{
          valid: dispatch[i],
          src1_ready: !rename_in.instr[i].op.rden1 || src_rdy[2*i],
          src2_ready: !rename_in.instr[i].op.rden2 || src_rdy[2*i+1],
          comp: ~(&rename_in.instr[i].instr[1:0]),
          psrc1: rename_in.rat.psrc[2*i],
          psrc2: rename_in.rat.psrc[2*i+1],
          pdest: pdest_arr[i],
          rob_tag: rename_in.rob_tag[i],
          rdata1: rename_in.instr[i].op.rden1 ? src_data[2*i] : 32'h0,
          rdata2: rename_in.instr[i].op.rden2 ? src_data[2*i+1] : 32'h0,
          imm: rename_in.instr[i].imm,
          pc: rename_in.instr[i].pc,
          caddr: rename_in.instr[i].caddr,
          op: rename_in.instr[i].op,
          unit_op:
          rename_in.instr[i].op.bitm
          ?
          UNIT_OP_BITS'(rename_in.instr[i].bit_op)
          :
          rename_in.instr[i].op.mult
          ?
          UNIT_OP_BITS'(rename_in.instr[i].mul_op)
          :
          rename_in.instr[i].op.division
          ?
          UNIT_OP_BITS'(rename_in.instr[i].div_op)
          :
          rename_in.instr[i].op.csreg
          ?
          UNIT_OP_BITS'(rename_in.instr[i].csr_op)
          :
          rename_in.instr[i].op.branch
          ?
          UNIT_OP_BITS'(rename_in.instr[i].bcu_op)
          : (
          rename_in.instr[i].op.load | rename_in.instr[i].op.store
          ) ?
          UNIT_OP_BITS'(rename_in.instr[i].lsu_op)
          :
          UNIT_OP_BITS
          '(
          rename_in.instr[i].alu_op
          )
      };

      rename_out.rs_entry[i] = e;

      re = '{
          valid: 1'b1,
          done: init_rob_entry.done,
          exception: init_rob_entry.exception,
          ecause: init_rob_entry.ecause,
          pc: rename_in.instr[i].pc,
          pnpc: rename_in.instr[i].npc,
          pred: rename_in.instr[i].pred,
          result: init_rob_entry.result,
          target: init_rob_entry.target,
          wdata: init_rob_entry.wdata,
          store_strb: init_rob_entry.store_strb,
          pdest: pdest_arr[i],
          old_pdest: rename_in.rat.old_pdest[i],
          adest: rename_in.instr[i].waddr,
          wren: rename_in.instr[i].op.wren && (rename_in.instr[i].waddr != 5'h0),
          store: rename_in.instr[i].op.store,
          branch: rename_in.instr[i].op.branch,
          jump: rename_in.instr[i].op.jal | rename_in.instr[i].op.jalr,
          mret: rename_in.instr[i].op.mret,
          fence: rename_in.instr[i].op.fence,
          ecall: rename_in.instr[i].op.ecall,
          ebreak: rename_in.instr[i].op.ebreak,
          wfi: rename_in.instr[i].op.wfi,
          csreg: rename_in.instr[i].op.csreg,
          cwren: rename_in.instr[i].op.cwren,
          caddr: rename_in.instr[i].caddr
      };

      rename_out.rob_entry[i] = re;

      rename_out.fl.alloc[i] = dispatch[i] && need_fl[i];

      rename_out.rat.rsrc_a[2*i]   = rename_in.instr[i].op.rden1 ? rename_in.instr[i].raddr1 : 5'h0;
      rename_out.rat.rsrc_a[2*i+1] = rename_in.instr[i].op.rden2 ? rename_in.instr[i].raddr2 : 5'h0;

      rename_out.rat.waddr_a[i] = rename_in.instr[i].waddr;
      rename_out.rat.waddr_p[i] = pdest_arr[i];
      rename_out.rat.wren[i]    = dispatch[i] && rename_in.instr[i].op.wren && (rename_in.instr[i].waddr != 5'h0);

      rename_out.rob_alloc[i] = dispatch[i];

      rename_out.rs_int_alloc[i] = dispatch[i] && !is_mem[i];
      rename_out.rs_mem_alloc[i] = dispatch[i] && is_mem[i];
    end
  end
endmodule
