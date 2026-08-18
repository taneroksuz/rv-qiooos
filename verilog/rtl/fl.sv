import configure::*;
import wires::*;
import functions::*;
module fl (
  input  logic       reset,
  input  logic       clock,
  input  logic       flush,
  input  fl_in_type  fl_in,
  output fl_out_type fl_out
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    logic [FL_CNT_BITS-1:0] spec_head;
    logic [FL_CNT_BITS-1:0] comm_head;
    logic [FL_CNT_BITS-1:0] tail;
    logic [FL_CNT_BITS-1:0] spec_count;
    logic [FL_CNT_BITS-1:0] comm_count;
    logic [FLIST_DEPTH-1:0] list_written;

    logic [ISSUE_WIDTH-1:0]                    do_free;
    logic [ISSUE_WIDTH-1:0][FL_IDX_BITS-1:0]   free_slot;
    logic [ISSUE_WIDTH-1:0][FL_IDX_BITS-1:0]   alloc_slot;
    logic [ISSUE_WIDTH-1:0][FL_CNT_BITS-1:0]   spec_head_pn;
    logic [ISSUE_WIDTH-1:0][0:0]               free_en;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] free_tag;
  } fl_reg_type;
  localparam fl_reg_type init_fl_reg = '{
      spec_head: '0,
      comm_head: '0,
      tail: FL_CNT_BITS'(FLIST_DEPTH),
      spec_count: FL_CNT_BITS'(FLIST_DEPTH),
      comm_count: FL_CNT_BITS'(FLIST_DEPTH),
      list_written: '0,
      do_free: '0,
      free_slot: '0,
      alloc_slot: '0,
      spec_head_pn: '0,
      free_en: '0,
      free_tag: '0
  };

  logic [PRF_ADDR_BITS-1:0] list[0:FLIST_DEPTH-1];

  fl_reg_type r, rin, v;

  always_comb begin
    v         = r;
    v.do_free = '0;

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.free_en[i]  = fl_in.free_en[i];
      v.free_tag[i] = fl_in.free_tag[i];
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.free_slot[i] = '0;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.spec_head_pn[i] = r.spec_head + FL_CNT_BITS'(i);
      v.alloc_slot[i]   = v.spec_head_pn[i][FL_IDX_BITS-1:0];
    end

    fl_out = '0;
    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      fl_out.alloc_tag[i] = r.list_written[v.alloc_slot[i]] ?
          list[v.alloc_slot[i]] : (PRF_ADDR_BITS'(ARCH_REGS) + PRF_ADDR_BITS'(v.alloc_slot[i]));
      fl_out.alloc_ok[i] = (r.spec_count >= FL_CNT_BITS'(i + 1));
    end
    fl_out.empty   = (r.spec_count == '0);
    fl_out.has_two = fl_out.alloc_ok[1];

    if (flush) begin
      v.spec_head  = r.comm_head;
      v.comm_head  = r.comm_head;
      v.spec_count = r.comm_count;

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        if (v.free_en[i]) begin
          v.do_free[i]                   = 1'b1;
          v.free_slot[i]                 = v.tail[FL_IDX_BITS-1:0];
          v.tail                         = v.tail + 1'b1;
          v.spec_head                    = v.spec_head + 1'b1;
          v.comm_head                    = v.comm_head + 1'b1;
          v.list_written[v.free_slot[i]] = 1'b1;
        end
      end
    end else begin
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        if (v.free_en[i] && (v.spec_count < FL_CNT_BITS'(FLIST_DEPTH))) begin
          v.do_free[i]                   = 1'b1;
          v.free_slot[i]                 = v.tail[FL_IDX_BITS-1:0];
          v.tail                         = v.tail + 1'b1;
          v.spec_count                   = v.spec_count + 1'b1;
          v.comm_head                    = v.comm_head + 1'b1;
          v.list_written[v.free_slot[i]] = 1'b1;
        end
      end

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        if (fl_in.alloc[i] && (v.spec_count >= 1)) begin
          v.spec_head  = v.spec_head + 1'b1;
          v.spec_count = v.spec_count - 1'b1;
        end
      end
    end
    rin = v;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_fl_reg;
    end else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset != 0) begin
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        if (rin.do_free[i]) begin
          list[rin.free_slot[i]] <= rin.free_tag[i];
        end
      end
    end
  end
endmodule
