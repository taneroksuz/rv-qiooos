import configure::*;
import constants::*;
import functions::*;
import wires::*;

module fetch (
  input  logic          reset,
  input  logic          clock,
  input  logic          flush,
  input  logic          stall,
  input  fetch_in_type  fetch_in,
  output fetch_out_type fetch_out
);
  timeunit 1ns; timeprecision 1ps;

  fetch_reg_type r, rin;
  fetch_reg_type v;

  always_comb begin

    v = r;

    v.fence = 0;
    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      v.fence = v.fence | fetch_in.entry[p].fence;
    end

    v.valid = 0;
    v.stall = fetch_in.buffer_out.stall;

    v.flush = v.fence;
    v.flush = v.flush | (|fetch_in.btac_out.pred_miss);
    v.flush = v.flush | fetch_in.btac_out.pred[0].taken | fetch_in.btac_out.pred[1].taken |
        fetch_in.btac_out.pred[2].taken | fetch_in.btac_out.pred[3].taken;
    v.flush = v.flush | fetch_in.csr_out.trap | fetch_in.csr_out.mret;

    if (fetch_in.cache_out.mem_ready == 1) begin
      v.rdata = fetch_in.cache_out.mem_rdata;
      v.ready = 1;
    end else begin
      v.ready = 0;
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      v.pc[s]         = fetch_in.buffer_out.pc[s];
      v.instr[s]      = fetch_in.buffer_out.instr[s];
      v.lane_ready[s] = fetch_in.buffer_out.ready[s];
    end

    if (stall == 1 && flush == 0) begin
      for (int s = 0; s < ISSUE_WIDTH; s++) begin
        v.pc[s]         = r.pc[s];
        v.instr[s]      = r.instr[s];
        v.lane_ready[s] = r.lane_ready[s];
      end
    end

    case (v.state)
      IDLE: begin
        v.state = BUSY;
        v.valid = 1;
        v.stall = 1;
      end
      BUSY: begin
        if (v.ready == 1) begin
          v.state = BUSY;
          v.valid = 1;
        end else if (v.flush == 1) begin
          v.state = INVALID;
          v.valid = 0;
          v.stall = 1;
        end else begin
          v.state = BUSY;
          v.valid = 0;
          v.stall = 1;
        end
      end
      INVALID: begin
        if (v.ready == 1) begin
          v.state = BUSY;
          v.ready = 0;
          v.valid = 1;
          v.stall = 1;
        end else begin
          v.state = INVALID;
          v.ready = 0;
          v.valid = 0;
          v.stall = 1;
        end
      end
      default: begin
      end
    endcase

    if (fetch_in.csr_out.trap == 1) begin
      v.ipc = fetch_in.csr_out.mtvec;
    end else if (fetch_in.csr_out.mret == 1) begin
      v.ipc = fetch_in.csr_out.mepc;
    end else if (fetch_in.entry[0].fence) begin
      v.ipc = fetch_in.entry[0].pnpc;
    end else if (fetch_in.entry[1].fence) begin
      v.ipc = fetch_in.entry[1].pnpc;
    end else if (fetch_in.entry[2].fence) begin
      v.ipc = fetch_in.entry[2].pnpc;
    end else if (fetch_in.entry[3].fence) begin
      v.ipc = fetch_in.entry[3].pnpc;
    end else if (fetch_in.btac_out.pred_miss[0]) begin
      v.ipc = fetch_in.btac_out.pred_maddr[0];
    end else if (fetch_in.btac_out.pred_miss[1]) begin
      v.ipc = fetch_in.btac_out.pred_maddr[1];
    end else if (fetch_in.btac_out.pred_miss[2]) begin
      v.ipc = fetch_in.btac_out.pred_maddr[2];
    end else if (fetch_in.btac_out.pred_miss[3]) begin
      v.ipc = fetch_in.btac_out.pred_maddr[3];
    end else if (fetch_in.btac_out.pred[0].taken) begin
      v.ipc = fetch_in.btac_out.pred[0].taddr;
    end else if (fetch_in.btac_out.pred[1].taken) begin
      v.ipc = fetch_in.btac_out.pred[1].taddr;
    end else if (fetch_in.btac_out.pred[2].taken) begin
      v.ipc = fetch_in.btac_out.pred[2].taddr;
    end else if (fetch_in.btac_out.pred[3].taken) begin
      v.ipc = fetch_in.btac_out.pred[3].taddr;
    end else if (v.stall == 0) begin
      v.ipc = v.ipc + PC_INCREMENTS;
    end

    fetch_out.buffer_in.pc    = r.ipc;
    fetch_out.buffer_in.rdata = v.rdata;
    fetch_out.buffer_in.ready = v.ready;
    fetch_out.buffer_in.clear = v.flush;
    fetch_out.buffer_in.stall = stall;

    fetch_out.cache_in.mem_valid = v.valid;
    fetch_out.cache_in.mem_addr  = v.ipc;
    fetch_out.cache_in.mem_fence = v.fence;

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      fetch_out.btac_in.get_pc[s] = v.pc[s];
    end
    for (int p = 0; p < ISSUE_WIDTH; p++) begin
      fetch_out.btac_in.upd_pc[p]     = fetch_in.entry[p].pc;
      fetch_out.btac_in.upd_npc[p]    = fetch_in.entry[p].pnpc;
      fetch_out.btac_in.upd_addr[p]   = fetch_in.entry[p].npc;
      fetch_out.btac_in.upd_jump[p]   = fetch_in.entry[p].jump;
      fetch_out.btac_in.upd_branch[p] = fetch_in.entry[p].branch;
      fetch_out.btac_in.upd_pred[p]   = fetch_in.entry[p].pred;
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      fetch_out.pc[s]    = v.pc[s];
      fetch_out.instr[s] = v.instr[s];
      fetch_out.ready[s] = v.lane_ready[s];
    end

    rin = v;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_fetch_reg;
    end else begin
      r <= rin;
    end
  end

endmodule
