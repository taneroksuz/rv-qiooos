import configure::*;
import constants::*;
import wires::*;
import functions::*;
module commit (
  input  logic           reset,
  input  logic           clock,
  input  logic           flush,
  input  commit_in_type  commit_in,
  output commit_out_type commit_out
);
  timeunit 1ns; timeprecision 1ps;
  typedef struct packed {
    csr_write_in_type                     csr_win;
    csr_exception_in_type                 csr_ein;
    rat_in_type                           rat_i;
    prf_in_type                           prf_i;
    fl_in_type                            fl_i;
    logic [0:0]                           flush_all;
    commit_entry_type [ISSUE_WIDTH-1:0]   commit_entry;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]      store_slot_valid;
    store_slot_type [MEM_ISSUE_WIDTH-1:0] store_slot_entry;
  } commit_reg_type;
  localparam commit_reg_type init_commit_reg = '{
      csr_win       : init_csr_write_in,
      csr_ein       : init_csr_exception_in,
      rat_i         : init_rat_in,
      prf_i         : init_prf_in,
      fl_i          : init_fl_in,
      flush_all     : 0,
      commit_entry  : '{default: init_commit_entry},
      store_slot_valid : '{default: 0},
      store_slot_entry : '{default: init_store_slot}
  };
  commit_reg_type r, rin;
  commit_reg_type v;
  rob_entry_type  e               [    0:ISSUE_WIDTH-1];
  logic           c               [    0:ISSUE_WIDTH-1];
  logic           entry_flush     [    0:ISSUE_WIDTH-1];
  logic           do_commit       [    0:ISSUE_WIDTH-1];
  logic           any_flush;
  logic           irq_take;
  logic           store_slot_found[0:MEM_ISSUE_WIDTH-1];
  int             store_slot_owner[0:MEM_ISSUE_WIDTH-1];
  always_comb begin
    v = init_commit_reg;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      e[k] = commit_in.entry[k];
      c[k] = commit_in.commit_valid[k];
    end

    irq_take = commit_in.irpt && c[0] && !e[0].exception;

    any_flush = 1'b0;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      do_commit[k]   = c[k] && !any_flush && !irq_take;
      entry_flush[k] = 1'b0;
      if (do_commit[k]) begin
        entry_flush[k] = e[k].exception | e[k].mret |
            (!e[k].branch ? e[k].jump & (~e[k].pred.taken | (e[k].target != e[k].pred.taddr)) : 0) |
            (e[k].branch ? e[k].jump ^ e[k].pred.taken : 0);
      end
      any_flush = any_flush | entry_flush[k];
    end

    v.flush_all = any_flush | irq_take;

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v.commit_entry[p] = init_commit_entry;
      if (do_commit[p]) begin
        v.commit_entry[p].pc     = e[p].pc;
        v.commit_entry[p].pnpc   = e[p].pnpc;
        v.commit_entry[p].target = e[p].target;
        v.commit_entry[p].pred   = e[p].pred;
        v.commit_entry[p].jump   = e[p].jump;
        v.commit_entry[p].branch = e[p].branch;
        v.commit_entry[p].fence  = e[p].fence;
      end
    end

    store_slot_found[0] = 1'b0;
    store_slot_found[1] = 1'b0;
    store_slot_owner[0] = 0;
    store_slot_owner[1] = 0;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (do_commit[k] && e[k].store) begin
        if (!store_slot_found[0]) begin
          store_slot_owner[0] = k;
          store_slot_found[0] = 1'b1;
        end else if (!store_slot_found[1]) begin
          store_slot_owner[1] = k;
          store_slot_found[1] = 1'b1;
        end
      end
    end
    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      v.store_slot_valid[p]            = store_slot_found[p];
      v.store_slot_entry[p]            = init_store_slot;
      v.store_slot_entry[p].exception  = e[store_slot_owner[p]].exception;
      v.store_slot_entry[p].target     = e[store_slot_owner[p]].target;
      v.store_slot_entry[p].wdata      = e[store_slot_owner[p]].wdata;
      v.store_slot_entry[p].store_strb = e[store_slot_owner[p]].store_strb;
    end

    if (irq_take) begin
      v.csr_ein.irpt = 1'b1;
      v.csr_ein.pc   = e[0].pc;
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (do_commit[k]) begin
        v.csr_ein.valid[k]      = 1'b1;
        v.prf_i.wren[k]         = e[k].wren & ~e[k].exception;
        v.prf_i.waddr[k]        = e[k].adest;
        v.prf_i.wdata[k]        = e[k].result;
        v.rat_i.commit_addr[k]  = e[k].adest;
        v.rat_i.commit_tag[k]   = e[k].pdest;
        v.rat_i.commit_valid[k] = e[k].wren & ~e[k].exception;
        v.fl_i.free_tag[k]      = e[k].old_pdest;
        v.fl_i.free_en[k]       = e[k].wren & ~e[k].exception;
        if (e[k].cwren) begin
          v.csr_win.cwren  = 1'b1;
          v.csr_win.cwaddr = e[k].caddr;
          v.csr_win.cdata  = e[k].wdata;
        end
        if (e[k].mret) begin
          v.csr_ein.mret = 1'b1;
          v.csr_ein.epc  = e[k].pc;
        end
        if (e[k].exception) begin
          v.csr_ein.exception = 1'b1;
          v.csr_ein.pc        = e[k].pc;
          v.csr_ein.epc       = e[k].pc;
          v.csr_ein.ecause    = e[k].ecause;
          v.csr_ein.etval     = e[k].result;
        end
      end
    end

    if (flush) begin
      v = init_commit_reg;
    end

    rin                = v;
    commit_out.csr_win = r.csr_win;
    commit_out.csr_ein = r.csr_ein;
    commit_out.rat_i   = r.rat_i;
    commit_out.prf_i   = r.prf_i;
    commit_out.fl_i    = r.fl_i;
    commit_out.flush   = r.flush_all;
    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      commit_out.commit_entry[p] = r.commit_entry[p];
    end
    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      commit_out.store_slot_valid[p] = r.store_slot_valid[p];
      commit_out.store_slot_entry[p] = r.store_slot_entry[p];
    end
  end
  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_commit_reg;
    end else begin
      r <= rin;
    end
  end
endmodule
