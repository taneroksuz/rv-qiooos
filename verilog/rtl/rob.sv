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

  localparam ROB_BANKS     = ISSUE_WIDTH;
  localparam ROB_ROWS      = ROB_DEPTH / ROB_BANKS;
  localparam ROB_BANK_BITS = $clog2(ROB_BANKS);
  localparam ROB_ROW_BITS  = $clog2(ROB_ROWS);
  localparam ROB_WPORTS    = ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH;

  typedef struct packed {
    logic [ROB_ADDR_BITS-1:0]                  head;
    logic [ROB_ADDR_BITS-1:0]                  tail_ptr;
    logic [ROB_ADDR_BITS:0]                    count;
    logic [ROB_DEPTH-1:0]                      valid_bits;
    rob_entry_type [ISSUE_WIDTH-1:0]           h;
    rob_entry_type [ISSUE_WIDTH-1:0]           alloc_entry_w;
    logic [ISSUE_WIDTH-1:0]                    h_done;
    logic [ISSUE_WIDTH-1:0]                    h_stop;
    logic [ISSUE_WIDTH-1:0]                    commit;
    logic [31:0]                               store_count;
    logic [31:0]                               store_room;
    logic [ISSUE_WIDTH-1:0]                    alloc_ok;
    logic [ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] tail_idx;
    logic [ISSUE_WIDTH-1:0][ROB_ADDR_BITS-1:0] head_idx;
    logic [ROB_WPORTS-1:0][ROB_ADDR_BITS-1:0]  wtag;
    rob_entry_type [ROB_WPORTS-1:0]            wentry;
    logic [ROB_WPORTS-1:0]                     wen;
    logic [ROB_WPORTS-1:0]                     wv;
    logic [ISSUE_WIDTH-1:0][ROB_WPORTS-1:0]    h_hit;
    logic [ROB_BANK_BITS-1:0]                  head_bank;
    logic [ROB_BANK_BITS-1:0]                  tail_bank;
    logic [ROB_ROW_BITS-1:0]                   head_row;
    logic [ROB_ROW_BITS-1:0]                   tail_row;
    rob_entry_type [ROB_BANKS-1:0]             bank_rdata;
    logic [ROB_BANKS-1:0][ROB_ROW_BITS-1:0]    bank_rrow;
    rob_entry_type [ROB_BANKS-1:0]             bank_wdata;
    logic [ROB_BANKS-1:0][ROB_ROW_BITS-1:0]    bank_wrow;
    logic [ROB_BANKS-1:0]                      bank_wen;
    logic [ROB_BANKS-1:0][ROB_BANK_BITS-1:0]   bank_lane;
  } rob_reg_type;

  localparam rob_reg_type init_rob_reg = '{
      head: '0,
      tail_ptr: '0,
      count: '0,
      valid_bits: '0,
      h: '{default: init_rob_entry},
      alloc_entry_w: '{default: init_rob_entry},
      wentry: '{default: init_rob_entry},
      bank_rdata: '{default: init_rob_entry},
      bank_wdata: '{default: init_rob_entry},
      default: '0
  };

  rob_entry_type array[0:ROB_DEPTH-1];

  rob_reg_type r, rin, v;

  always_comb begin
    v = r;
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.commit[k]   = 1'b0;
      v.alloc_ok[k] = 1'b0;
      v.head_idx[k] = r.head + ROB_ADDR_BITS'(unsigned'(k));
      v.h_done[k]   = 1'b0;
      v.h_stop[k]   = 1'b0;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.tail_idx[i] = r.tail_ptr;
    end

    for (int i = 0; i < ISSUE_WIDTH; i++) begin
      v.alloc_entry_w[i]       = rob_in.alloc_entry[i];
      v.alloc_entry_w[i].valid = 1'b1;
    end

    v.head_bank = r.head[ROB_BANK_BITS-1:0];
    v.head_row  = r.head[ROB_ADDR_BITS-1:ROB_BANK_BITS];
    for (int b = 0; b < ROB_BANKS; b++) begin
      v.bank_rrow[b]  = v.head_row + ROB_ROW_BITS'((b < int'(v.head_bank)) ? 1 : 0);
      v.bank_rdata[b] = array[int'(v.bank_rrow[b])*ROB_BANKS+b];
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.h[k]       = v.bank_rdata[(int'(v.head_bank)+k)&(ROB_BANKS-1)];
      v.h[k].valid = r.valid_bits[v.head_idx[k]];
    end

    for (int p = 0; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
      v.wtag[p]   = rob_in.write_tag[p];
      v.wentry[p] = rob_in.write_entry[p];
      v.wen[p]    = rob_in.write_en[p];
    end

    for (int p = 0; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
      v.wv[p] = v.wen[p] && r.valid_bits[v.wtag[p]];
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        v.h_hit[k][p] = v.wv[p] && (v.wtag[p] == v.head_idx[k]);
      end
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      for (int p = 0; p < ISSUE_WIDTH; p++) begin
        if (v.h_hit[k][p]) begin
          v.h[k].done       = 1'b1;
          v.h[k].result     = v.wentry[p].result;
          v.h[k].exception  = v.wentry[p].exception;
          v.h[k].ecause     = v.wentry[p].ecause;
          v.h[k].target     = v.wentry[p].target;
          v.h[k].branch     = v.wentry[p].branch;
          v.h[k].jump       = v.wentry[p].jump;
          v.h[k].wdata      = v.wentry[p].wdata;
          v.h[k].store_strb = v.wentry[p].store_strb;
        end
      end

      for (int p = ISSUE_WIDTH; p < ISSUE_WIDTH + MEM_ISSUE_WIDTH; p++) begin
        if (v.h_hit[k][p]) begin
          v.h[k].done      = 1'b1;
          v.h[k].result    = v.wentry[p].result;
          v.h[k].exception = v.wentry[p].exception;
          v.h[k].ecause    = v.wentry[p].ecause;
        end
      end

      for (int p = ISSUE_WIDTH + MEM_ISSUE_WIDTH; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
        if (v.h_hit[k][p]) begin
          v.h[k].done       = 1'b1;
          v.h[k].target     = v.wentry[p].target;
          v.h[k].wdata      = v.wentry[p].wdata;
          v.h[k].store_strb = v.wentry[p].store_strb;
          v.h[k].exception  = v.wentry[p].exception;
          v.h[k].ecause     = v.wentry[p].ecause;
          v.h[k].result     = v.wentry[p].result;
        end
      end
    end

    for (int i = 0; i < ROB_DEPTH; i++) begin
      rob_store_pending[i] = (flush ? 1'b0 : r.valid_bits[i]) & array[i].store;
    end

    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      v.h_done[k] = v.h[k].valid && v.h[k].done && (r.count >= (ROB_ADDR_BITS + 1)'(k + 1));
      v.h_stop[k] = v.h[k].exception || v.h[k].mret || (v.h[k].jump && (v.h[k].target != v.h[k].pnpc)) ||
          v.h[k].fence || v.h[k].wfi || v.h[k].ecall || v.h[k].ebreak || v.h[k].csreg;
    end

    rob_out = init_rob_out;
    if (!flush) begin
      rob_out.head_ptr = r.head;
      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        rob_out.alloc_tag[i] = r.tail_ptr + ROB_ADDR_BITS'(i);
        rob_out.alloc_ok[i]  = (r.count <= ROB_DEPTH - ISSUE_WIDTH);
        rob_out.entry[i]     = v.h[i];
      end
    end

    v.store_room = 0;
    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      if (rob_in.store_slot_free[p]) begin
        v.store_room = v.store_room + 1;
      end
    end

    v.store_count = 0;
    v.commit[0]   = v.h_done[0] && (!v.h[0].store || (v.store_count < v.store_room));
    if (v.commit[0] && v.h[0].store) begin
      v.store_count = v.store_count + 1;
    end
    for (int k = 1; k < ISSUE_WIDTH; k++) begin
      v.commit[k] = v.h_done[k] && v.commit[k-1] && !v.h_stop[k-1] && (!v.h[k].store || (v.store_count < v.store_room));
      if (v.commit[k] && v.h[k].store) begin
        v.store_count = v.store_count + 1;
      end
    end
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rob_out.commit_valid[k] = flush ? 1'b0 : v.commit[k];
    end

    if (flush) begin
      v.head       = '0;
      v.tail_ptr   = '0;
      v.count      = '0;
      v.valid_bits = '0;
    end
    else begin
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (v.commit[k]) begin
          v.valid_bits[v.head] = 1'b0;
          v.head               = v.head + ROB_ADDR_BITS'(1);
          v.count              = v.count - 1'b1;
        end
      end

      for (int i = 0; i < ISSUE_WIDTH; i++) begin
        v.alloc_ok[i] = rob_in.alloc[i] && (v.count < ROB_DEPTH);
        if (v.alloc_ok[i]) begin
          v.tail_idx[i]            = v.tail_ptr;
          v.valid_bits[v.tail_ptr] = 1'b1;
          v.tail_ptr               = v.tail_ptr + ROB_ADDR_BITS'(1);
          v.count                  = v.count + 1'b1;
        end
      end
    end

    v.tail_bank = r.tail_ptr[ROB_BANK_BITS-1:0];
    v.tail_row  = r.tail_ptr[ROB_ADDR_BITS-1:ROB_BANK_BITS];
    for (int b = 0; b < ROB_BANKS; b++) begin
      v.bank_lane[b]  = ROB_BANK_BITS'(b) - v.tail_bank;
      v.bank_wdata[b] = v.alloc_entry_w[v.bank_lane[b]];
      v.bank_wrow[b]  = v.tail_row + ROB_ROW_BITS'((b < int'(v.tail_bank)) ? 1 : 0);
      v.bank_wen[b]   = v.alloc_ok[v.bank_lane[b]];
    end

    rin = v;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_rob_reg;
    end
    else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int i = 0; i < ROB_DEPTH; i++) begin
        array[i] <= init_rob_entry;
      end
    end
    else begin
      if (!flush) begin
        for (int b = 0; b < ROB_BANKS; b++) begin
          for (int row = 0; row < ROB_ROWS; row++) begin
            if (rin.bank_wen[b] && (int'(rin.bank_wrow[b]) == row)) begin
              array[row*ROB_BANKS+b] <= rin.bank_wdata[b];
            end
          end
        end

        for (int p = 0; p < ISSUE_WIDTH; p++) begin
          if (rin.wen[p] && rin.valid_bits[rin.wtag[p]]) begin
            array[rin.wtag[p]].done       <= 1'b1;
            array[rin.wtag[p]].result     <= rin.wentry[p].result;
            array[rin.wtag[p]].exception  <= rin.wentry[p].exception;
            array[rin.wtag[p]].ecause     <= rin.wentry[p].ecause;
            array[rin.wtag[p]].target     <= rin.wentry[p].target;
            array[rin.wtag[p]].branch     <= rin.wentry[p].branch;
            array[rin.wtag[p]].jump       <= rin.wentry[p].jump;
            array[rin.wtag[p]].wdata      <= rin.wentry[p].wdata;
            array[rin.wtag[p]].store_strb <= rin.wentry[p].store_strb;
          end
        end
        for (int p = ISSUE_WIDTH; p < ISSUE_WIDTH + MEM_ISSUE_WIDTH; p++) begin
          if (rin.wen[p] && rin.valid_bits[rin.wtag[p]]) begin
            array[rin.wtag[p]].done      <= 1'b1;
            array[rin.wtag[p]].result    <= rin.wentry[p].result;
            array[rin.wtag[p]].exception <= rin.wentry[p].exception;
            array[rin.wtag[p]].ecause    <= rin.wentry[p].ecause;
          end
        end
        for (int p = ISSUE_WIDTH + MEM_ISSUE_WIDTH; p < ISSUE_WIDTH + 2 * MEM_ISSUE_WIDTH; p++) begin
          if (rin.wen[p] && rin.valid_bits[rin.wtag[p]]) begin
            array[rin.wtag[p]].done       <= 1'b1;
            array[rin.wtag[p]].target     <= rin.wentry[p].target;
            array[rin.wtag[p]].wdata      <= rin.wentry[p].wdata;
            array[rin.wtag[p]].store_strb <= rin.wentry[p].store_strb;
            array[rin.wtag[p]].exception  <= rin.wentry[p].exception;
            array[rin.wtag[p]].ecause     <= rin.wentry[p].ecause;
            array[rin.wtag[p]].result     <= rin.wentry[p].result;
          end
        end
      end
    end
  end
endmodule
