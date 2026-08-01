import configure::*;
import constants::*;
import wires::*;
import functions::*;
module rs_mem (
  input  logic           reset,
  input  logic           clock,
  input  logic           flush,
  input  rs_mem_in_type  rs_in,
  input  rob_entry_type  rob_entries[0:ROB_DEPTH-1],
  output rs_mem_out_type rs_out
);
  timeunit 1ns; timeprecision 1ps;
  localparam MEM_ADDR_BITS = $clog2(RS_MEM_DEPTH);

  typedef struct packed {
    logic [MEM_ADDR_BITS:0]  count;
    logic [RS_MEM_DEPTH-1:0] valid_bits;
  } rs_mem_reg_type;

  localparam rs_mem_reg_type init_rs_mem_reg = '{count: '0, valid_bits: '0};

  rs_entry_type array[0:RS_MEM_DEPTH-1];
  rs_mem_reg_type r, rin, v;
  rs_entry_type                       woken             [   0:RS_MEM_DEPTH-1];
  rs_entry_type                       cur_entry;
  logic         [  MEM_ADDR_BITS-1:0] sel_idx           [0:MEM_ISSUE_WIDTH-1];
  logic                               sel_found         [0:MEM_ISSUE_WIDTH-1];
  logic         [  MEM_ADDR_BITS-1:0] free_idx          [    0:ISSUE_WIDTH-1];
  logic                               free_found        [    0:ISSUE_WIDTH-1];
  logic         [  ROB_ADDR_BITS-1:0] best_age          [0:MEM_ISSUE_WIDTH-1];
  logic         [  ROB_ADDR_BITS-1:0] cand_age;
  logic         [      ROB_DEPTH-1:0] store_valid;
  logic         [  ROB_ADDR_BITS-1:0] store_age         [      0:ROB_DEPTH-1];
  logic                               older_store_block;
  logic         [  MEM_ADDR_BITS-1:0] oldest_idx        [0:MEM_ISSUE_WIDTH-1];
  logic                               oldest_found      [0:MEM_ISSUE_WIDTH-1];
  logic                               oldest_ready      [0:MEM_ISSUE_WIDTH-1];
  logic         [MEM_ISSUE_WIDTH-1:0] port_busy;
  logic                               free_cond;

  function automatic logic [ROB_ADDR_BITS-1:0] rob_age(input logic [ROB_ADDR_BITS-1:0] head,
                                                       input logic [ROB_ADDR_BITS-1:0] tag);
    rob_age = tag - head;
  endfunction

  always_comb begin
    rs_out            = '0;
    v                 = r;
    rin               = r;
    sel_idx           = '{default: '0};
    sel_found         = '{default: 1'b0};
    free_idx          = '{default: '0};
    free_found        = '{default: 1'b0};
    best_age          = '{default: '0};
    cand_age          = '0;
    older_store_block = 1'b0;
    oldest_idx        = '{default: '0};
    oldest_found      = '{default: 1'b0};
    oldest_ready      = '{default: 1'b0};
    port_busy         = rs_in.load_busy;

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      cur_entry       = r.valid_bits[i] ? array[i] : init_rs_entry;
      cur_entry.valid = r.valid_bits[i];
      woken[i]        = rs_wakeup(cur_entry, rs_in.cdb[0]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb[1]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb[2]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb[3]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb_load[0]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb_load[1]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb_commit[0]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb_commit[1]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb_commit[2]);
      woken[i]        = rs_wakeup(woken[i], rs_in.cdb_commit[3]);

      if (woken[i].valid) begin
        cand_age = rob_age(rs_in.rob_head, woken[i].rob_tag);
        if (!oldest_found[0] || (cand_age < best_age[0])) begin
          if (oldest_found[0]) begin
            oldest_idx[1]   = oldest_idx[0];
            oldest_found[1] = 1'b1;
            best_age[1]     = best_age[0];
          end
          oldest_idx[0]   = MEM_ADDR_BITS'(unsigned'(i));
          oldest_found[0] = 1'b1;
          best_age[0]     = cand_age;
        end else if (!oldest_found[1] || (cand_age < best_age[1])) begin
          oldest_idx[1]   = MEM_ADDR_BITS'(unsigned'(i));
          oldest_found[1] = 1'b1;
          best_age[1]     = cand_age;
        end
      end

    end

    for (int j = 0; j < ROB_DEPTH; j++) begin
      store_valid[j] = rob_entries[j].valid && rob_entries[j].store;
      store_age[j]   = rob_age(rs_in.rob_head, ROB_ADDR_BITS'(unsigned'(j)));
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      if (oldest_found[p]) begin
        older_store_block = 1'b0;
        if (woken[oldest_idx[p]].op.load) begin
          for (int j = 0; j < ROB_DEPTH; j++) begin
            if (store_valid[j] && (store_age[j] < best_age[p])) begin
              older_store_block = 1'b1;
            end
          end
        end
        oldest_ready[p] = woken[oldest_idx[p]].src1_ready && woken[oldest_idx[p]].src2_ready &&
            (woken[oldest_idx[p]].op.store || (woken[oldest_idx[p]].op.load && !older_store_block));
      end
    end
    sel_found[0] = 1'b0;
    sel_found[1] = 1'b0;
    if (oldest_found[0] && oldest_ready[0]) begin
      if (!port_busy[0]) begin
        sel_idx[0]   = oldest_idx[0];
        sel_found[0] = 1'b1;
      end else if (!port_busy[1]) begin
        sel_idx[1]   = oldest_idx[0];
        sel_found[1] = 1'b1;
      end
    end
    if (sel_found[0] && oldest_found[1] && oldest_ready[1]) begin
      if (!(woken[oldest_idx[0]].op.load ^ woken[oldest_idx[1]].op.load)) begin
        if (!port_busy[1]) begin
          sel_idx[1]   = oldest_idx[1];
          sel_found[1] = 1'b1;
        end
      end
    end

    for (int i = 0; i < RS_MEM_DEPTH; i++) begin
      free_cond = (!woken[i].valid || (sel_found[0] && (sel_idx[0] == MEM_ADDR_BITS'(unsigned'(i))))
                   || (sel_found[1] && (sel_idx[1] == MEM_ADDR_BITS'(unsigned'(i)))));
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (free_cond && !free_found[k]) begin
          free_idx[k]   = MEM_ADDR_BITS'(unsigned'(i));
          free_found[k] = 1'b1;
          break;
        end
      end
    end

    for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
      rs_out.issue[p]       = sel_found[p] ? woken[sel_idx[p]] : init_rs_entry;
      rs_out.issue_valid[p] = sel_found[p];
    end
    rs_out.full         = (r.count >= (MEM_ADDR_BITS + 1)'(RS_MEM_DEPTH - 1));
    rs_out.has_two_free = (r.count <= (MEM_ADDR_BITS + 1)'(RS_MEM_DEPTH - 2));
    for (int k = 0; k < ISSUE_WIDTH; k++) begin
      rs_out.alloc_ok[k] = (r.count <= (MEM_ADDR_BITS + 1)'(RS_MEM_DEPTH - ISSUE_WIDTH));
    end

    if (flush) begin
      rs_out     = '0;
      sel_found  = '{default: 1'b0};
      free_found = '{default: 1'b0};
      v          = init_rs_mem_reg;
    end else begin
      for (int p = 0; p < MEM_ISSUE_WIDTH; p++) begin
        if (sel_found[p]) begin
          v.valid_bits[sel_idx[p]] = 1'b0;
          v.count                  = v.count - 1'b1;
        end
      end
      for (int k = 0; k < ISSUE_WIDTH; k++) begin
        if (rs_in.alloc[k] && free_found[k]) begin
          v.valid_bits[free_idx[k]] = 1'b1;
          v.count                   = v.count + 1'b1;
        end
      end
    end
    rin = v;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_rs_mem_reg;
    end else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset != 0) begin
      if (!flush) begin
        for (int i = 0; i < RS_MEM_DEPTH; i++) begin
          if (rs_in.alloc[0] && free_found[0] &&
              (free_idx[0] == MEM_ADDR_BITS'(unsigned'(i)))) begin
            array[i] <= rs_in.entry[0];
          end else if (rs_in.alloc[1] && free_found[1] &&
                       (free_idx[1] == MEM_ADDR_BITS'(unsigned'(i)))) begin
            array[i] <= rs_in.entry[1];
          end else if (rs_in.alloc[2] && free_found[2] &&
                       (free_idx[2] == MEM_ADDR_BITS'(unsigned'(i)))) begin
            array[i] <= rs_in.entry[2];
          end else if (rs_in.alloc[3] && free_found[3] &&
                       (free_idx[3] == MEM_ADDR_BITS'(unsigned'(i)))) begin
            array[i] <= rs_in.entry[3];
          end else if (r.valid_bits[i] && rin.valid_bits[i] &&
                       !(sel_found[0] && (sel_idx[0] == MEM_ADDR_BITS'(unsigned'(i)))) &&
                       !(sel_found[1] && (sel_idx[1] == MEM_ADDR_BITS'(unsigned'(i))))) begin
            array[i] <= woken[i];
          end
        end
      end
    end
  end
endmodule
