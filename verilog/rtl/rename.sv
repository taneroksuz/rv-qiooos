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

  instruction_type                     instr       [ISSUE_WIDTH];
  logic                                squash      [ISSUE_WIDTH];
  logic                                instr_valid [ISSUE_WIDTH];
  logic                                is_mem      [ISSUE_WIDTH];
  logic                                need_fl     [ISSUE_WIDTH];
  logic                                rs_ok       [ISSUE_WIDTH];
  logic                                fl_ok       [ISSUE_WIDTH];
  logic                                can_dispatch[ISSUE_WIDTH];
  logic                                dispatch    [ISSUE_WIDTH];
  logic            [PRF_ADDR_BITS-1:0] pdest_arr   [ISSUE_WIDTH];

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

    squash[0] = 1'b0;
    for (int i = 1; i < ISSUE_WIDTH; i++) begin
      squash[i] = squash[i-1] | rename_in.btac_out.pred[i-1].taken;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      instr[i] = rename_in.instr[i];
      if (squash[i]) begin
        instr[i].op = init_operation;
      end
      instr[i].pred.taken = rename_in.btac_out.pred[i].taken;
      instr[i].pred.taddr = rename_in.btac_out.pred[i].taddr;
      instr[i].pred.tsat  = rename_in.btac_out.pred[i].tsat;

      instr_valid[i] = instr[i].op.valid;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      fl_tag_arr[i] = rename_in.fl.alloc_tag[i];
      fl_ok_arr[i]  = rename_in.fl.alloc_ok[i];
    end

    rob_ok = rename_in.rob_alloc_ok[0];

    fl_count = 0;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      is_mem[i]  = instr_valid[i] && (instr[i].op.load || instr[i].op.store);
      need_fl[i] = instr_valid[i] && instr[i].op.wren && (instr[i].waddr != 5'h0);

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

    can_dispatch[0] = instr_valid[0] && rob_ok && rs_ok[0] && fl_ok[0] && !flush;
    for (int i = 1; i < ISSUE_WIDTH; i++) begin
      can_dispatch[i] = instr_valid[i] && can_dispatch[i-1] && rob_ok && rs_ok[i] && fl_ok[i] && !flush;
    end

    stall = 1'b0;
    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      if (instr_valid[i] && !can_dispatch[i]) begin
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
          src1_ready: !instr[i].op.rden1 || src_rdy[2*i],
          src2_ready: !instr[i].op.rden2 || src_rdy[2*i+1],
          comp: ~(&instr[i].instr[1:0]),
          psrc1: rename_in.rat.psrc[2*i],
          psrc2: rename_in.rat.psrc[2*i+1],
          pdest: pdest_arr[i],
          rob_tag: rename_in.rob_tag[i],
          rdata1: instr[i].op.rden1 ? src_data[2*i] : 32'h0,
          rdata2: instr[i].op.rden2 ? src_data[2*i+1] : 32'h0,
          imm: instr[i].imm,
          pc: instr[i].pc,
          caddr: instr[i].caddr,
          op: instr[i].op,
          unit_op:
          instr[i].op.bitm
          ?
          UNIT_OP_BITS'(instr[i].bit_op)
          :
          instr[i].op.mult
          ?
          UNIT_OP_BITS'(instr[i].mul_op)
          :
          instr[i].op.division
          ?
          UNIT_OP_BITS'(instr[i].div_op)
          :
          instr[i].op.csreg
          ?
          UNIT_OP_BITS'(instr[i].csr_op)
          :
          instr[i].op.branch
          ?
          UNIT_OP_BITS'(instr[i].bcu_op)
          : (
          instr[i].op.load | instr[i].op.store
          ) ?
          UNIT_OP_BITS'(instr[i].lsu_op)
          :
          UNIT_OP_BITS
          '(
          instr[i].alu_op
          )
      };

      rename_out.rs_entry[i] = e;

      re = '{
          valid: 1'b1,
          done: init_rob_entry.done,
          exception: init_rob_entry.exception,
          ecause: init_rob_entry.ecause,
          pc: instr[i].pc,
          pnpc: instr[i].npc,
          pred: instr[i].pred,
          result: init_rob_entry.result,
          target: init_rob_entry.target,
          wdata: init_rob_entry.wdata,
          store_strb: init_rob_entry.store_strb,
          pdest: pdest_arr[i],
          old_pdest: rename_in.rat.old_pdest[i],
          adest: instr[i].waddr,
          wren: instr[i].op.wren && (instr[i].waddr != 5'h0),
          store: instr[i].op.store,
          branch: instr[i].op.branch,
          jump: instr[i].op.jal | instr[i].op.jalr,
          mret: instr[i].op.mret,
          fence: instr[i].op.fence,
          ecall: instr[i].op.ecall,
          ebreak: instr[i].op.ebreak,
          wfi: instr[i].op.wfi,
          csreg: instr[i].op.csreg,
          cwren: instr[i].op.cwren,
          caddr: instr[i].caddr
      };

      rename_out.rob_entry[i] = re;

      rename_out.fl.alloc[i] = dispatch[i] && need_fl[i];

      rename_out.rat.rsrc_a[2*i]   = instr[i].op.rden1 ? instr[i].raddr1 : 5'h0;
      rename_out.rat.rsrc_a[2*i+1] = instr[i].op.rden2 ? instr[i].raddr2 : 5'h0;

      rename_out.rat.waddr_a[i] = instr[i].waddr;
      rename_out.rat.waddr_p[i] = pdest_arr[i];
      rename_out.rat.wren[i]    = dispatch[i] && instr[i].op.wren && (instr[i].waddr != 5'h0);

      rename_out.rob_alloc[i] = dispatch[i];

      rename_out.rs_int_alloc[i] = dispatch[i] && !is_mem[i];
      rename_out.rs_mem_alloc[i] = dispatch[i] && is_mem[i];
    end
  end

endmodule
