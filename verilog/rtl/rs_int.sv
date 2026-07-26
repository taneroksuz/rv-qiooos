import configure::*;
import constants::*;
import wires::*;
import functions::*;
module rs_int (
  input  logic           reset,
  input  logic           clock,
  input  logic           flush,
  input  rs_int_in_type  rs_in,
  output rs_int_out_type rs_out
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    logic [RS_ADDR_BITS:0]        count;
    logic [RS_INT_DEPTH-1:0]      valid_bits;
    logic [3:0][RS_ADDR_BITS-1:0] sel_idx;
    logic [3:0]                   sel_found;
    logic [3:0][RS_ADDR_BITS-1:0] free_idx;
    logic [3:0]                   free_found;
    logic [3:0]                   csr_inflight;
    logic [0:0]                   csr_drain;
    rs_int_out_type               rs_o;
  } rs_int_reg_type;

  localparam rs_int_out_type init_rs_int_out = '0;

  localparam rs_int_reg_type init_rs_int_reg = '{
      count: '0,
      valid_bits: '0,
      sel_idx: '0,
      sel_found: '0,
      free_idx: '0,
      free_found: '0,
      csr_inflight: '0,
      csr_drain: 1'b0,
      rs_o: init_rs_int_out
  };

  rs_entry_type                    array     [0:RS_INT_DEPTH-1];
  rs_entry_type                    view      [0:RS_INT_DEPTH-1];
  rs_entry_type                    woken     [0:RS_INT_DEPTH-1];
  logic         [RS_INT_DEPTH-1:0] ready_vec;
  rs_int_reg_type r, rin, v;

  rs_entry_type issue_arr[0:3];

  int mul_budget, div_budget, clmul_budget, agu_budget, bcu_budget;
  int bitalu_budget, csralu_budget;
  int   sel_count;
  logic csr_taken;
  logic needs_bcu, needs_agu, can_take;
  logic issue_free;

  always_comb begin
    v            = r;
    v.sel_idx    = '0;
    v.sel_found  = '0;
    v.free_idx   = '0;
    v.free_found = '0;
    v.rs_o       = init_rs_int_out;

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      view[i] = r.valid_bits[i] ? array[i] : init_rs_entry;
      view[i].valid = r.valid_bits[i];
      woken[i] = rs_wakeup(view[i], rs_in.cdb[0]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb[1]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb[2]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb[3]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb_load[0]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb_load[1]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb_commit[0]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb_commit[1]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb_commit[2]);
      woken[i] = rs_wakeup(woken[i], rs_in.cdb_commit[3]);
      ready_vec[i] = woken[i].valid & woken[i].src1_ready &
          woken[i].src2_ready & ~rs_in.div_busy & ~rs_in.clmul_busy & ~(
          woken[i].op.csreg & (r.csr_inflight > 0)) & ~(woken[i].op.csreg & r.csr_drain) & ~(
          woken[i].op.csreg & (woken[i].rob_tag != rs_in.rob_head));
    end

    begin
      mul_budget    = 2;
      div_budget    = 1;
      clmul_budget  = 1;
      agu_budget    = 2;
      bcu_budget    = 2;
      bitalu_budget = 2;
      csralu_budget = 2;
      sel_count     = 0;
      csr_taken     = 1'b0;

      for (int i = RS_INT_DEPTH - 1; i >= 0; i--) begin
        needs_bcu = woken[i].op.branch;
        needs_agu = woken[i].op.auipc | woken[i].op.jal | woken[i].op.jalr | woken[i].op.branch;

        if (woken[i].op.mult) can_take = (mul_budget > 0);
        else if (woken[i].op.division) can_take = (div_budget > 0);
        else if (woken[i].op.bitc) can_take = (clmul_budget > 0);
        else if (woken[i].op.bitm) can_take = (bitalu_budget > 0);
        else if (woken[i].op.csreg) can_take = (csralu_budget > 0);
        else if (needs_bcu) can_take = (agu_budget > 0) && (bcu_budget > 0);
        else if (needs_agu) can_take = (agu_budget > 0);
        else can_take = 1'b1;

        if (ready_vec[i] && (sel_count < 4) && !csr_taken) begin
          if (can_take) begin
            v.sel_idx[sel_count]   = RS_ADDR_BITS'(unsigned'(i));
            v.sel_found[sel_count] = 1'b1;
            sel_count              = sel_count + 1;

            if (woken[i].op.mult) mul_budget = mul_budget - 1;
            else if (woken[i].op.division) div_budget = div_budget - 1;
            else if (woken[i].op.bitc) clmul_budget = clmul_budget - 1;
            else if (woken[i].op.bitm) bitalu_budget = bitalu_budget - 1;
            else if (woken[i].op.csreg) begin
              csralu_budget = csralu_budget - 1;
              csr_taken     = 1'b1;
            end else if (needs_bcu) begin
              agu_budget = agu_budget - 1;
              bcu_budget = bcu_budget - 1;
            end else if (needs_agu) begin
              agu_budget = agu_budget - 1;
            end
          end
        end
      end
    end

    for (int i = 0; i < RS_INT_DEPTH; i++) begin
      issue_free = 1'b0;
      for (int k = 0; k < 4; k++) begin
        if (v.sel_found[k] && (v.sel_idx[k] == RS_ADDR_BITS'(unsigned'(i)))) begin
          issue_free = 1'b1;
        end
      end
      for (int k = 0; k < 4; k++) begin
        if ((!woken[i].valid || issue_free) && !v.free_found[k]) begin
          v.free_idx[k]   = RS_ADDR_BITS'(unsigned'(i));
          v.free_found[k] = 1'b1;
          break;
        end
      end
    end

    for (int k = 0; k < 4; k++) begin
      issue_arr[k]          = v.sel_found[k] ? woken[v.sel_idx[k]] : init_rs_entry;
      v.rs_o.issue[k]       = issue_arr[k];
      v.rs_o.issue_valid[k] = v.sel_found[k];
    end

    v.rs_o.full         = (r.count >= (RS_ADDR_BITS + 1)'(RS_INT_DEPTH - 1));
    v.rs_o.has_two_free = (r.count <= (RS_ADDR_BITS + 1)'(RS_INT_DEPTH - 2));
    for (int k = 0; k < 4; k++) begin
      v.rs_o.alloc_ok[k] = (r.count <= (RS_ADDR_BITS + 1)'(RS_INT_DEPTH - 4));
    end

    v.rs_o.csr_rin = '0;
    for (int k = 0; k < 4; k++) begin
      if (v.sel_found[k] && issue_arr[k].op.csreg) begin
        v.rs_o.csr_rin.crden  = 1'b1;
        v.rs_o.csr_rin.craddr = issue_arr[k].caddr;
      end
    end

    if (flush) begin
      v.count      = '0;
      v.valid_bits = '0;
      v.sel_found  = '0;
      v.free_found = '0;
      v.rs_o       = init_rs_int_out;
    end else begin
      for (int k = 0; k < 4; k++) begin
        if (v.sel_found[k]) begin
          v.valid_bits[v.sel_idx[k]] = 1'b0;
          v.count                    = v.count - 1'b1;
        end
      end
      for (int k = 0; k < 4; k++) begin
        if (rs_in.alloc[k] && v.free_found[k]) begin
          v.valid_bits[v.free_idx[k]] = 1'b1;
          v.count                     = v.count + 1'b1;
        end
      end
      v.csr_drain = 1'b0;
      for (int k = 0; k < 4; k++) begin
        if (v.sel_found[k] && issue_arr[k].op.csreg && issue_arr[k].op.cwren) begin
          v.csr_inflight = v.csr_inflight + 4'b1;
        end
      end
      if (rs_in.csr_commit && v.csr_inflight > 0) begin
        if (v.csr_inflight == 4'b1) begin
          v.csr_drain = 1'b1;
        end
        v.csr_inflight = v.csr_inflight - 4'b1;
      end
    end

    rin    = v;
    rs_out = rin.rs_o;
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_rs_int_reg;
    end else begin
      r <= rin;
    end
  end

  always_ff @(posedge clock) begin
    if (reset != 0) begin
      for (int i = 0; i < RS_INT_DEPTH; i++) begin
        if (rs_in.alloc[0] && rin.free_found[0] &&
            (rin.free_idx[0] == RS_ADDR_BITS'(unsigned'(i)))) begin
          array[i] <= rs_in.entry[0];
        end else if (rs_in.alloc[1] && rin.free_found[1] &&
                     (rin.free_idx[1] == RS_ADDR_BITS'(unsigned'(i)))) begin
          array[i] <= rs_in.entry[1];
        end else if (rs_in.alloc[2] && rin.free_found[2] &&
                     (rin.free_idx[2] == RS_ADDR_BITS'(unsigned'(i)))) begin
          array[i] <= rs_in.entry[2];
        end else if (rs_in.alloc[3] && rin.free_found[3] &&
                     (rin.free_idx[3] == RS_ADDR_BITS'(unsigned'(i)))) begin
          array[i] <= rs_in.entry[3];
        end else if (r.valid_bits[i] && rin.valid_bits[i] &&
                     !((rin.sel_found[0] && (rin.sel_idx[0] == RS_ADDR_BITS'(unsigned'(i)))) ||
                       (rin.sel_found[1] && (rin.sel_idx[1] == RS_ADDR_BITS'(unsigned'(i)))) ||
                       (rin.sel_found[2] && (rin.sel_idx[2] == RS_ADDR_BITS'(unsigned'(i)))) ||
                       (rin.sel_found[3] && (rin.sel_idx[3] == RS_ADDR_BITS'(unsigned'(i)))))) begin
          array[i] <= woken[i];
        end
      end
    end
  end
endmodule
