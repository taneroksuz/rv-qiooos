import configure::*;
import constants::*;
import wires::*;
import functions::*;

module msu (
  input  logic        reset,
  input  logic        clock,
  input  logic        flush,
  input  msu_in_type  msu_in,
  output msu_out_type msu_out
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    cdb_type [MEM_ISSUE_WIDTH-1:0]                 cdb;
    logic [MEM_ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] rob_wtag;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0]           rob_wentry;
    logic [MEM_ISSUE_WIDTH-1:0]                    rob_wen;
    mem_in_type [MEM_ISSUE_WIDTH-1:0]              dmem_in;
    lsu_in_type [MEM_ISSUE_WIDTH-1:0]              lsu_in;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]               load_pending;
    logic [MEM_ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] load_rob_tag;
    logic [MEM_ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] load_pdest;
    logic [MEM_ISSUE_WIDTH-1:0][31:0]              load_addr;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]               store_pending;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]               store_sent;
    rob_entry_type [MEM_ISSUE_WIDTH-1:0]           store_entry;
    logic [MEM_ISSUE_WIDTH-1:0][0:0]               load_sent;
  } msu_reg_type;

  localparam msu_reg_type init_msu_reg = '{cdb            : '{default: init_cdb}, rob_wtag       : '{default: '0}, rob_wentry     : '{default: init_rob_entry}, rob_wen        : '{default: 1'b0}, dmem_in        : '{default: init_mem_in}, lsu_in         : '{default: '{ldata : 32'h0, byteenable : 4'h0, lsu_op : init_lsu_op}}, load_pending   : '{default: 1'b0}, load_sent      : '{default: 1'b0}, load_rob_tag   : '{default: '0}, load_pdest     : '{default: '0}, load_addr      : '{default: '0}, store_pending  : '{default: 1'b0}, store_sent     : '{default: 1'b0}, store_entry    : '{default: init_rob_entry}};

  msu_reg_type r, rin, v;
  logic load_accept       [0:MEM_ISSUE_WIDTH-1];
  logic load_ready        [0:MEM_ISSUE_WIDTH-1];
  logic commit_store_valid[0:MEM_ISSUE_WIDTH-1];
  logic load_busy[0:MEM_ISSUE_WIDTH-1], store_busy[0:MEM_ISSUE_WIDTH-1];
  logic store_done        [0:MEM_ISSUE_WIDTH-1];
  logic store_slot_free   [0:MEM_ISSUE_WIDTH-1];
  logic slot_free_pre     [0:MEM_ISSUE_WIDTH-1];
  logic commit_claims_slot[0:MEM_ISSUE_WIDTH-1];
  logic slot_blocked      [0:MEM_ISSUE_WIDTH-1];

  always_comb begin
    v = r;
    if (flush) begin
      for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
        v.load_pending[p] = 1'b0;
        v.load_sent[p]    = 1'b0;
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      v.lsu_in[p].ldata = msu_in.dmem_out[p].mem_rdata;
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      commit_store_valid[p] = msu_in.commit_store[p] && !msu_in.commit_entry[p].exception;
      load_busy[p]          = r.load_pending[p] && !msu_in.dmem_out[p].mem_ready;
      store_busy[p]         = r.store_pending[p] && !msu_in.dmem_out[p].mem_ready;
      store_done[p]         = r.store_pending[p] && r.store_sent[p] && msu_in.dmem_out[p].mem_ready;
      slot_free_pre[p]      = !r.store_pending[p] || store_done[p];
    end

    commit_claims_slot[0] = 1'b0;
    commit_claims_slot[1] = 1'b0;
    for (int c = 0; c < MEM_ISSUE_WIDTH; c++) begin
      if (commit_store_valid[c]) begin
        if (slot_free_pre[0] && !commit_claims_slot[0]) begin
          commit_claims_slot[0] = 1'b1;
        end else if (slot_free_pre[1] && !commit_claims_slot[1]) begin
          commit_claims_slot[1] = 1'b1;
        end
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      slot_blocked[p] = load_busy[p] || store_busy[p] || commit_claims_slot[p];
      load_accept[p]  = msu_in.issue_valid[p] && msu_in.issue[p].op.load && !slot_blocked[p] && !flush;
      load_ready[p]   = r.load_pending[p] && !r.store_pending[p] && msu_in.dmem_out[p].mem_ready && !flush;
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      if (load_accept[p] && !msu_in.agu_out[p].exception) begin
        v.load_pending[p]      = 1'b1;
        v.load_sent[p]         = 1'b0;
        v.load_rob_tag[p]      = msu_in.issue[p].rob_tag;
        v.load_pdest[p]        = msu_in.issue[p].pdest;
        v.load_addr[p]         = msu_in.agu_out[p].address;
        v.lsu_in[p].byteenable = msu_in.agu_out[p].byteenable;
        v.lsu_in[p].lsu_op     = msu_in.issue[p].lsu_op;
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      if (store_done[p]) begin
        v.store_pending[p] = 1'b0;
        v.store_sent[p]    = 1'b0;
      end
      store_slot_free[p] = !v.store_pending[p];
    end
    for (int c = 0; c < MEM_ISSUE_WIDTH; c++) begin
      if (commit_store_valid[c]) begin
        if (store_slot_free[0]) begin
          v.store_pending[0] = 1'b1;
          v.store_sent[0]    = 1'b0;
          v.store_entry[0]   = msu_in.commit_entry[c];
          store_slot_free[0] = 1'b0;
        end else if (store_slot_free[1]) begin
          v.store_pending[1] = 1'b1;
          v.store_sent[1]    = 1'b0;
          v.store_entry[1]   = msu_in.commit_entry[c];
          store_slot_free[1] = 1'b0;
        end
      end
    end
    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      if (load_ready[p]) begin
        v.load_pending[p] = (load_accept[p] && !msu_in.agu_out[p].exception) ? 1'b1 : 1'b0;
        v.load_sent[p]    = 1'b0;
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      v.dmem_in[p] = init_mem_in;
      if (v.store_pending[p] && !v.store_sent[p]) begin
        v.dmem_in[p].mem_valid = 1'b1;
        v.dmem_in[p].mem_instr = 1'b0;
        v.dmem_in[p].mem_mode  = 2'h0;
        v.dmem_in[p].mem_addr  = v.store_entry[p].store_addr;
        v.dmem_in[p].mem_wdata = v.store_entry[p].store_data;
        v.dmem_in[p].mem_wstrb = v.store_entry[p].store_strb;
        v.store_sent[p]        = 1'b1;
      end else if (v.load_pending[p] && !v.load_sent[p]) begin
        v.dmem_in[p].mem_valid = 1'b1;
        v.dmem_in[p].mem_instr = 1'b0;
        v.dmem_in[p].mem_mode  = 2'h0;
        v.dmem_in[p].mem_addr  = v.load_addr[p];
        v.dmem_in[p].mem_wdata = 32'h0;
        v.dmem_in[p].mem_wstrb = 4'h0;
        v.load_sent[p]         = 1'b1;
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      v.cdb[p]        = init_cdb;
      v.rob_wtag[p]   = r.load_rob_tag[p];
      v.rob_wentry[p] = init_rob_entry;
      v.rob_wen[p]    = 1'b0;

      if (load_accept[p] && msu_in.agu_out[p].exception) begin
        v.rob_wtag[p]             = msu_in.issue[p].rob_tag;
        v.rob_wen[p]              = 1'b1;
        v.rob_wentry[p].done      = 1'b1;
        v.rob_wentry[p].exception = 1'b1;
        v.rob_wentry[p].ecause    = msu_in.agu_out[p].ecause;
        v.rob_wentry[p].etval     = msu_in.agu_out[p].etval;
      end else if (load_ready[p]) begin
        v.cdb[p].valid         = 1'b1;
        v.cdb[p].tag           = r.load_pdest[p];
        v.cdb[p].data          = msu_in.lsu_out[p].result;
        v.rob_wen[p]           = 1'b1;
        v.rob_wentry[p].done   = 1'b1;
        v.rob_wentry[p].result = msu_in.lsu_out[p].result;
      end
    end

    rin = v;

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      msu_out.cdb[p]        = r.cdb[p];
      msu_out.rob_wtag[p]   = r.rob_wtag[p];
      msu_out.rob_wentry[p] = r.rob_wentry[p];
      msu_out.rob_wen[p]    = r.rob_wen[p];
      msu_out.dmem_in[p]    = v.dmem_in[p];
      msu_out.lsu_in[p]     = v.lsu_in[p];
      if (load_ready[p]) begin
        msu_out.lsu_in[p].byteenable = r.lsu_in[p].byteenable;
        msu_out.lsu_in[p].lsu_op     = r.lsu_in[p].lsu_op;
      end
    end
    msu_out.load_busy   = {slot_blocked[1], slot_blocked[0]};
    msu_out.store_ready = !(r.store_pending[0] || r.store_pending[1]) && !(msu_in.commit_store[0] || msu_in.commit_store[1]);
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_msu_reg;
    end else begin
      r <= rin;
    end
  end
endmodule
