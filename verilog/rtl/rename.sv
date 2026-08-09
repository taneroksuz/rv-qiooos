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

  typedef struct packed {
    logic [0:0]               is_mem;
    logic [0:0]               need_fl;
    logic [0:0]               rs_ok;
    logic [0:0]               fl_ok;
    logic [0:0]               can_dispatch;
    logic [PRF_ADDR_BITS-1:0] pdest;
    rs_entry_type             e;
    rs_entry_type             em;
  } lane_type;

  typedef struct packed {
    logic                       rob_ok;
    logic                       int_room_ok;
    logic                       stall;
    lane_type [ISSUE_WIDTH-1:0] l;
    rename_out_type             rename_out;
  } rename_reg_type;

  rename_reg_type v;
  cdb_type        cdb_load_any;

  instruction_type                     instr      [0:ISSUE_WIDTH-1];
  logic            [              0:0] instr_valid[0:ISSUE_WIDTH-1];
  logic            [ROB_ADDR_BITS-1:0] rob_tag    [0:ISSUE_WIDTH-1];

  logic [PRF_ADDR_BITS-1:0] psrc_arr      [0:2*ISSUE_WIDTH-1];
  logic [              0:0] psrc_valid_arr[0:2*ISSUE_WIDTH-1];
  logic [             31:0] prf_rdata_arr [0:2*ISSUE_WIDTH-1];
  logic [              0:0] prf_rvalid_arr[0:2*ISSUE_WIDTH-1];

  logic [PRF_ADDR_BITS-1:0] fl_tag_arr[0:ISSUE_WIDTH-1];
  logic [              0:0] fl_ok_arr [0:ISSUE_WIDTH-1];

  logic [0:0] can_dispatch_final[0:ISSUE_WIDTH-1];

  lane_type lanes    [0:ISSUE_WIDTH-1];
  int       fl_count;
  int       fl_idx;

  always_comb begin
    v            = '0;
    v.rename_out = '0;
    cdb_load_any = rename_in.cdb_load[0].valid ? rename_in.cdb_load[0] : rename_in.cdb_load[1];

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      instr[i]       = rename_in.instr[i];
      instr_valid[i] = rename_in.instr_valid[i];
      rob_tag[i]     = rename_in.rob_tag[i];
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      psrc_arr[i]       = rename_in.rat.psrc[i];
      psrc_valid_arr[i] = rename_in.rat.psrc_valid[i];
      prf_rdata_arr[i]  = rename_in.prf.rdata[i];
      prf_rvalid_arr[i] = rename_in.prf.rvalid[i];
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      fl_tag_arr[i] = rename_in.fl.alloc_tag[i];
      fl_ok_arr[i]  = rename_in.fl.alloc_ok[i];
    end

    v.rob_ok      = rename_in.rob_alloc_ok[0];
    v.int_room_ok = rename_in.rs_int_alloc_ok[0];

    begin
      fl_count = 0;

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        lanes[i]         = '0;
        lanes[i].is_mem  = instr_valid[i] && (instr[i].op.load || instr[i].op.store);
        lanes[i].need_fl = instr_valid[i] && instr[i].op.wren && (instr[i].waddr != 5'h0);

        if (lanes[i].is_mem) begin
          lanes[i].rs_ok = rename_in.rs_mem_alloc_ok[0];
        end else begin
          lanes[i].rs_ok = v.int_room_ok;
        end

        if (lanes[i].need_fl) begin
          lanes[i].fl_ok = fl_ok_arr[fl_count];
          fl_count       = fl_count + 1;
        end else begin
          lanes[i].fl_ok = 1'b1;
        end
      end

      lanes[0].can_dispatch = instr_valid[0] && v.rob_ok && lanes[0].rs_ok && lanes[0].fl_ok &&
          !flush;
      for (int i = 1; i < ISSUE_WIDTH; i++) begin
        lanes[i].can_dispatch = instr_valid[i] && lanes[i-1].can_dispatch && v.rob_ok &&
            lanes[i].rs_ok && lanes[i].fl_ok && !flush;
      end

      v.stall = 1'b0;
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        if (instr_valid[i] && !lanes[i].can_dispatch) begin
          v.stall = 1'b1;
        end
      end

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        can_dispatch_final[i] = v.stall ? 1'b0 : lanes[i].can_dispatch;
      end

      begin
        fl_idx = 0;
        for (int i = 0; i < ISSUE_WIDTH; i++) begin
          if (lanes[i].need_fl) begin
            lanes[i].pdest = fl_tag_arr[fl_idx];
            fl_idx         = fl_idx + 1;
          end else begin
            lanes[i].pdest = PRF_ADDR_BITS'(0);
          end
        end
      end

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        lanes[i].e = init_rs_entry;
        lanes[i].e.valid = can_dispatch_final[i] && !lanes[i].is_mem;
        lanes[i].e.psrc1 = psrc_arr[2*i];
        lanes[i].e.psrc2 = psrc_arr[2*i+1];
        lanes[i].e.src1_ready = !instr[i].op.rden1 || src_ready(
            psrc_arr[2*i], psrc_valid_arr[2*i] && prf_rvalid_arr[2*i], rename_in.cdb, cdb_load_any);
        lanes[i].e.src2_ready = !instr[i].op.rden2 || src_ready(
          psrc_arr[2*i+1],
          psrc_valid_arr[2*i+1] && prf_rvalid_arr[2*i+1],
          rename_in.cdb,
          cdb_load_any
        );
        lanes[i].e.rdata1 = instr[i].op.rden1 ? prf_or_cdb(
          psrc_arr[2*i],
          psrc_valid_arr[2*i] && prf_rvalid_arr[2*i],
          prf_rdata_arr[2*i],
          rename_in.cdb,
          cdb_load_any
        ) : 32'h0;
        lanes[i].e.rdata2 = instr[i].op.rden2 ? prf_or_cdb(
          psrc_arr[2*i+1],
          psrc_valid_arr[2*i+1] && prf_rvalid_arr[2*i+1],
          prf_rdata_arr[2*i+1],
          rename_in.cdb,
          cdb_load_any
        ) : 32'h0;
        lanes[i].e.pdest = lanes[i].pdest;
        lanes[i].e.rob_tag = rob_tag[i];
        lanes[i].e.imm = instr[i].imm;
        lanes[i].e.pc = instr[i].pc;
        lanes[i].e.npc = instr[i].npc;
        lanes[i].e.caddr = instr[i].caddr;
        lanes[i].e.op = instr[i].op;
        lanes[i].e.alu_op = instr[i].alu_op;
        lanes[i].e.bcu_op = instr[i].bcu_op;
        lanes[i].e.lsu_op = instr[i].lsu_op;
        lanes[i].e.csr_op = instr[i].csr_op;
        lanes[i].e.div_op = instr[i].div_op;
        lanes[i].e.mul_op = instr[i].mul_op;
        lanes[i].e.bit_op = instr[i].bit_op;

        lanes[i].em       = lanes[i].e;
        lanes[i].em.valid = can_dispatch_final[i] && lanes[i].is_mem;
      end

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        v.l[i] = lanes[i];
      end
    end

    v.rename_out.stall = v.stall;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.rename_out.fl.alloc[i] = can_dispatch_final[i] && v.l[i].need_fl;

      v.rename_out.rat.rsrc_a[2*i]   = instr[i].op.rden1 ? instr[i].raddr1 : 5'h0;
      v.rename_out.rat.rsrc_a[2*i+1] = instr[i].op.rden2 ? instr[i].raddr2 : 5'h0;

      v.rename_out.rat.waddr_a[i] = instr[i].waddr;
      v.rename_out.rat.waddr_p[i] = v.l[i].pdest;
      v.rename_out.rat.wren[i] = can_dispatch_final[i] && instr[i].op.wren &&
          (instr[i].waddr != 5'h0);

      v.rename_out.rob_alloc[i] = can_dispatch_final[i];

      v.rename_out.rs_int_entry[i] = v.l[i].e;
      v.rename_out.rs_int_alloc[i] = v.l[i].e.valid;

      v.rename_out.rs_mem_entry[i] = v.l[i].em;
      v.rename_out.rs_mem_alloc[i] = v.l[i].em.valid;

      v.rename_out.rob_entry[i]           = init_rob_entry;
      v.rename_out.rob_entry[i].valid     = 1'b1;
      v.rename_out.rob_entry[i].pc        = instr[i].pc;
      v.rename_out.rob_entry[i].npc       = instr[i].npc;
      v.rename_out.rob_entry[i].pnpc      = instr[i].npc;
      v.rename_out.rob_entry[i].pred      = instr[i].pred;
      v.rename_out.rob_entry[i].pdest     = v.l[i].pdest;
      v.rename_out.rob_entry[i].adest     = instr[i].waddr;
      v.rename_out.rob_entry[i].wren      = instr[i].op.wren && (instr[i].waddr != 5'h0);
      v.rename_out.rob_entry[i].old_pdest = rename_in.rat.old_pdest[i];
      v.rename_out.rob_entry[i].store     = instr[i].op.store;
      v.rename_out.rob_entry[i].load      = instr[i].op.load;
      v.rename_out.rob_entry[i].lsu_op    = instr[i].lsu_op;
      v.rename_out.rob_entry[i].branch    = instr[i].op.branch;
      v.rename_out.rob_entry[i].jump      = instr[i].op.jal | instr[i].op.jalr;
      v.rename_out.rob_entry[i].mret      = instr[i].op.mret;
      v.rename_out.rob_entry[i].fence     = instr[i].op.fence;
      v.rename_out.rob_entry[i].ecall     = instr[i].op.ecall;
      v.rename_out.rob_entry[i].ebreak    = instr[i].op.ebreak;
      v.rename_out.rob_entry[i].wfi       = instr[i].op.wfi;
      v.rename_out.rob_entry[i].csreg     = instr[i].op.csreg;
      v.rename_out.rob_entry[i].cwren     = instr[i].op.cwren;
      v.rename_out.rob_entry[i].caddr     = instr[i].caddr;
    end

    rename_out = v.rename_out;
  end
endmodule
