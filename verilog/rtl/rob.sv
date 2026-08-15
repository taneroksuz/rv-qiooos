import configure::*;
import constants::*;
import wires::*;
import functions::*;
module rob (
  input  logic                        reset,
  input  logic                        clock,
  input  logic                        flush,
  input  rob_in_type                  rob_in,
  output rob_out_type                 rob_out,
  output logic        [ROB_DEPTH-1:0] rob_store_pending
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    logic [ROB_ADDR_BITS-1:0] head;
    logic [ROB_ADDR_BITS-1:0] tail_ptr;
    logic [ROB_ADDR_BITS:0]   count;
    logic [ROB_DEPTH-1:0]     valid_bits;
  } rob_reg_type;

  localparam rob_reg_type init_rob_reg = '{head: '0, tail_ptr: '0, count: '0, valid_bits: '0};

  localparam ROB_BANKS = ISSUE_WIDTH;
  localparam ROB_ROWS = ROB_DEPTH / ROB_BANKS;
  localparam ROB_BANK_BITS = $clog2(ROB_BANKS);
  localparam ROB_ROW_BITS = $clog2(ROB_ROWS);

  rob_entry_type array[0:ROB_DEPTH-1];
  rob_reg_type r, rin, v;
  rob_entry_type h[0:ISSUE_WIDTH-1];
  rob_entry_type alloc_entry_w[0:ISSUE_WIDTH-1];
  logic h_done[0:ISSUE_WIDTH-1];
  logic h_stop[0:ISSUE_WIDTH-1];
  logic commit[0:ISSUE_WIDTH-1];
  int store_count;
  logic [ISSUE_WIDTH-1:0] alloc_ok;
  logic [ROB_ADDR_BITS-1:0] tail_idx[0:ISSUE_WIDTH-1];
  logic [ROB_ADDR_BITS-1:0] head_idx[0:ISSUE_WIDTH-1];
  logic [ROB_ADDR_BITS-1:0] wtag[0:ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1];
  rob_entry_type wentry[0:ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1];
  logic wen[0:ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1];
  logic wv[0:ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1];
  logic h_hit[0:ISSUE_WIDTH-1][0:ISSUE_WIDTH+2*MEM_ISSUE_WIDTH-1];

  logic [ROB_BANK_BITS-1:0] head_bank, tail_bank;
  logic [ROB_ROW_BITS-1:0] head_row, tail_row;
  rob_entry_type                     bank_rdata[0:ROB_BANKS-1];
  logic          [ ROB_ROW_BITS-1:0] bank_rrow [0:ROB_BANKS-1];
  rob_entry_type                     bank_wdata[0:ROB_BANKS-1];
  logic          [ ROB_ROW_BITS-1:0] bank_wrow [0:ROB_BANKS-1];
  logic                              bank_wen  [0:ROB_BANKS-1];
  logic          [ROB_BANK_BITS-1:0] bank_lane [0:ROB_BANKS-1];

  always_comb begin
    v = r;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      commit[k]   = 1'b0;
      alloc_ok[k] = 1'b0;
      head_idx[k] = r.head + ROB_ADDR_BITS'(unsigned'(k));
      h_done[k]   = 1'b0;
      h_stop[k]   = 1'b0;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      tail_idx[i] = r.tail_ptr;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      alloc_entry_w[i]       = rob_in.alloc_entry[i];
      alloc_entry_w[i].valid = 1'b1;
    end

    head_bank = r.head[ROB_BANK_BITS-1:0];
    head_row  = r.head[ROB_ADDR_BITS-1:ROB_BANK_BITS];
    for (int b = 0; b < ROB_BANKS; b++) begin
      bank_rrow[b]  = head_row + ROB_ROW_BITS'((b < int'(head_bank)) ? 1 : 0);
      bank_rdata[b] = array[int'(bank_rrow[b])*ROB_BANKS+b];
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      h[k]       = bank_rdata[(int'(head_bank)+k)&(ROB_BANKS-1)];
      h[k].valid = r.valid_bits[head_idx[k]];
    end

    for (int p = 0; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
      wtag[p]   = rob_in.write_tag[p];
      wentry[p] = rob_in.write_entry[p];
      wen[p]    = rob_in.write_en[p];
    end

    for (int p = 0; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
      wv[p] = wen[p] && r.valid_bits[wtag[p]];
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        h_hit[k][p] = wv[p] && (wtag[p] == head_idx[k]);
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      for (int p = 0; p < ISSUE_WIDTH; p++) begin
        if (h_hit[k][p]) begin
          h[k].done       = 1'b1;
          h[k].result     = wentry[p].result;
          h[k].exception  = wentry[p].exception;
          h[k].ecause     = wentry[p].ecause;
          h[k].target     = wentry[p].target;
          h[k].branch     = wentry[p].branch;
          h[k].jump       = wentry[p].jump;
          h[k].wdata      = wentry[p].wdata;
          h[k].store_strb = wentry[p].store_strb;
        end
      end

      for (int p = ISSUE_WIDTH; p < ISSUE_WIDTH + MEM_ISSUE_WIDTH; p++) begin
        if (h_hit[k][p]) begin
          h[k].done      = 1'b1;
          h[k].result    = wentry[p].result;
          h[k].exception = wentry[p].exception;
          h[k].ecause    = wentry[p].ecause;
        end
      end

      for (int p = ISSUE_WIDTH + MEM_ISSUE_WIDTH; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
        if (h_hit[k][p]) begin
          h[k].done       = 1'b1;
          h[k].target     = wentry[p].target;
          h[k].wdata      = wentry[p].wdata;
          h[k].store_strb = wentry[p].store_strb;
          h[k].exception  = wentry[p].exception;
          h[k].ecause     = wentry[p].ecause;
          h[k].result     = wentry[p].result;
        end
      end
    end

    for (int i = 0; i < ROB_DEPTH; i++) begin
      rob_store_pending[i] = (flush ? 1'b0 : r.valid_bits[i]) & array[i].store;
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      h_done[k] = h[k].valid && h[k].done && (r.count >= (ROB_ADDR_BITS + 1)'(k + 1));
      h_stop[k] = h[k].exception || h[k].mret || (h[k].jump && (h[k].target != h[k].pnpc)) ||
          h[k].fence || h[k].wfi || h[k].ecall || h[k].ebreak || h[k].csreg;
    end

    rob_out = init_rob_out;
    if (!flush) begin
      rob_out.head_ptr = r.head;
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        rob_out.alloc_tag[i] = r.tail_ptr + ROB_ADDR_BITS'(i);
        rob_out.alloc_ok[i]  = (r.count <= ROB_DEPTH - ISSUE_WIDTH);
        rob_out.entry[i]     = h[i];
      end
    end

    store_count = 0;
    commit[0]   = h_done[0] && (!h[0].store || (store_count < MEM_ISSUE_WIDTH));
    if (commit[0] && h[0].store) begin
      store_count = store_count + 1;
    end
    for (int k = 1; k < ISSUE_WIDTH; k++) begin
      commit[k] = h_done[k] && commit[k-1] && !h_stop[k-1] &&
          (!h[k].store || (store_count < MEM_ISSUE_WIDTH));
      if (commit[k] && h[k].store) begin
        store_count = store_count + 1;
      end
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rob_out.commit_valid[k] = flush ? 1'b0 : commit[k];
    end

    if (flush) begin
      v = init_rob_reg;
    end else begin
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (commit[k]) begin
          v.valid_bits[v.head] = 1'b0;
          v.head               = v.head + ROB_ADDR_BITS'(1);
          v.count              = v.count - 1'b1;
        end
      end

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        alloc_ok[i] = rob_in.alloc[i] && (v.count < ROB_DEPTH);
        if (alloc_ok[i]) begin
          tail_idx[i]              = v.tail_ptr;
          v.valid_bits[v.tail_ptr] = 1'b1;
          v.tail_ptr               = v.tail_ptr + ROB_ADDR_BITS'(1);
          v.count                  = v.count + 1'b1;
        end
      end
    end

    tail_bank = r.tail_ptr[ROB_BANK_BITS-1:0];
    tail_row  = r.tail_ptr[ROB_ADDR_BITS-1:ROB_BANK_BITS];
    for (int b = 0; b < ROB_BANKS; b++) begin
      bank_lane[b]  = ROB_BANK_BITS'(b) - tail_bank;
      bank_wdata[b] = alloc_entry_w[bank_lane[b]];
      bank_wrow[b]  = tail_row + ROB_ROW_BITS'((b < int'(tail_bank)) ? 1 : 0);
      bank_wen[b]   = alloc_ok[bank_lane[b]];
    end

    rin = v;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_rob_reg;
    end else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset != 0) begin
      if (!flush) begin
        for (int b = 0; b < ROB_BANKS; b++) begin
          for (int row = 0; row < ROB_ROWS; row++) begin
            if (bank_wen[b] && (int'(bank_wrow[b]) == row)) begin
              array[row*ROB_BANKS+b] <= bank_wdata[b];
            end
          end
        end

        for (int p = 0; p < ISSUE_WIDTH; p++) begin
          if (wen[p] && rin.valid_bits[wtag[p]]) begin
            array[wtag[p]].done       <= 1'b1;
            array[wtag[p]].result     <= wentry[p].result;
            array[wtag[p]].exception  <= wentry[p].exception;
            array[wtag[p]].ecause     <= wentry[p].ecause;
            array[wtag[p]].target     <= wentry[p].target;
            array[wtag[p]].branch     <= wentry[p].branch;
            array[wtag[p]].jump       <= wentry[p].jump;
            array[wtag[p]].wdata      <= wentry[p].wdata;
            array[wtag[p]].store_strb <= wentry[p].store_strb;
          end
        end
        for (int p = ISSUE_WIDTH; p < ISSUE_WIDTH + MEM_ISSUE_WIDTH; p++) begin
          if (wen[p] && rin.valid_bits[wtag[p]]) begin
            array[wtag[p]].done      <= 1'b1;
            array[wtag[p]].result    <= wentry[p].result;
            array[wtag[p]].exception <= wentry[p].exception;
            array[wtag[p]].ecause    <= wentry[p].ecause;
          end
        end
        for (
            int p = ISSUE_WIDTH + MEM_ISSUE_WIDTH; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++
        ) begin
          if (wen[p] && rin.valid_bits[wtag[p]]) begin
            array[wtag[p]].done       <= 1'b1;
            array[wtag[p]].target     <= wentry[p].target;
            array[wtag[p]].wdata      <= wentry[p].wdata;
            array[wtag[p]].store_strb <= wentry[p].store_strb;
            array[wtag[p]].exception  <= wentry[p].exception;
            array[wtag[p]].ecause     <= wentry[p].ecause;
            array[wtag[p]].result     <= wentry[p].result;
          end
        end
      end
    end
  end
endmodule
