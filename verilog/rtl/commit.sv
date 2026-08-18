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

    rob_entry_type [ISSUE_WIDTH-1:0]  e;
    logic [ISSUE_WIDTH-1:0]           c;
    logic [ISSUE_WIDTH-1:0]           entry_flush;
    logic [ISSUE_WIDTH-1:0]           do_commit;
    logic [0:0]                       any_flush;
    logic [0:0]                       irq_take;
    logic [MEM_ISSUE_WIDTH-1:0]       store_slot_found;
    logic [MEM_ISSUE_WIDTH-1:0][31:0] store_slot_owner;
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
      store_slot_entry : '{default: init_store_slot},
      e                : '{default: init_rob_entry},
      default: '0
  };
  commit_reg_type r, rin;
  commit_reg_type v;
  always_comb begin
    v = init_commit_reg;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.e[k] = commit_in.entry[k];
      v.c[k] = commit_in.commit_valid[k];
    end

    v.irq_take = commit_in.irpt && v.c[0] && !v.e[0].exception;

    v.any_flush = 1'b0;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.do_commit[k]   = v.c[k] && !v.any_flush && !v.irq_take;
      v.entry_flush[k] = 1'b0;
      if (v.do_commit[k]) begin
        v.entry_flush[k] = v.e[k].exception | v.e[k].mret |
            (!v.e[k].branch ?
             v.e[k].jump & (~v.e[k].pred.taken | (v.e[k].target != v.e[k].pred.taddr)) : 0) |
            (v.e[k].branch ? v.e[k].jump ^ v.e[k].pred.taken : 0);
      end
      v.any_flush = v.any_flush | v.entry_flush[k];
    end

    v.flush_all = v.any_flush | v.irq_take;

    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v.commit_entry[p] = init_commit_entry;
      if (v.do_commit[p]) begin
        v.commit_entry[p].pc     = v.e[p].pc;
        v.commit_entry[p].pnpc   = v.e[p].pnpc;
        v.commit_entry[p].target = v.e[p].target;
        v.commit_entry[p].pred   = v.e[p].pred;
        v.commit_entry[p].jump   = v.e[p].jump;
        v.commit_entry[p].branch = v.e[p].branch;
        v.commit_entry[p].fence  = v.e[p].fence;
      end
    end

    v.store_slot_found[0] = 1'b0;
    v.store_slot_found[1] = 1'b0;
    v.store_slot_owner[0] = 0;
    v.store_slot_owner[1] = 0;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (v.do_commit[k] && v.e[k].store) begin
        if (!v.store_slot_found[0]) begin
          v.store_slot_owner[0] = k;
          v.store_slot_found[0] = 1'b1;
        end else if (!v.store_slot_found[1]) begin
          v.store_slot_owner[1] = k;
          v.store_slot_found[1] = 1'b1;
        end
      end
    end
    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      v.store_slot_valid[p]            = v.store_slot_found[p];
      v.store_slot_entry[p]            = init_store_slot;
      v.store_slot_entry[p].exception  = v.e[v.store_slot_owner[p]].exception;
      v.store_slot_entry[p].target     = v.e[v.store_slot_owner[p]].target;
      v.store_slot_entry[p].wdata      = v.e[v.store_slot_owner[p]].wdata;
      v.store_slot_entry[p].store_strb = v.e[v.store_slot_owner[p]].store_strb;
    end

    if (v.irq_take) begin
      v.csr_ein.irpt = 1'b1;
      v.csr_ein.pc   = v.e[0].pc;
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      if (v.do_commit[k]) begin
        v.csr_ein.valid[k]      = 1'b1;
        v.prf_i.wren[k]         = v.e[k].wren & ~v.e[k].exception;
        v.prf_i.waddr[k]        = v.e[k].adest;
        v.prf_i.wdata[k]        = v.e[k].result;
        v.rat_i.commit_addr[k]  = v.e[k].adest;
        v.rat_i.commit_tag[k]   = v.e[k].pdest;
        v.rat_i.commit_valid[k] = v.e[k].wren & ~v.e[k].exception;
        v.fl_i.free_tag[k]      = v.e[k].old_pdest;
        v.fl_i.free_en[k]       = v.e[k].wren & ~v.e[k].exception;
        if (v.e[k].cwren) begin
          v.csr_win.cwren  = 1'b1;
          v.csr_win.cwaddr = v.e[k].caddr;
          v.csr_win.cdata  = v.e[k].wdata;
        end
        if (v.e[k].mret) begin
          v.csr_ein.mret = 1'b1;
          v.csr_ein.epc  = v.e[k].pc;
        end
        if (v.e[k].exception) begin
          v.csr_ein.exception = 1'b1;
          v.csr_ein.pc        = v.e[k].pc;
          v.csr_ein.epc       = v.e[k].pc;
          v.csr_ein.ecause    = v.e[k].ecause;
          v.csr_ein.etval     = v.e[k].result;
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
