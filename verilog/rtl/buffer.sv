package buffer_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam BDEPTH = $clog2(BUFFER_DEPTH);
  localparam BWIDTH = $clog2(BUFFER_WIDTH);

  typedef struct packed {
    logic [BUFFER_WIDTH-1:0][0:0]        wen;
    logic [BUFFER_WIDTH-1:0][BDEPTH-1:0] waddr;
    logic [BUFFER_WIDTH-1:0][BDEPTH-1:0] raddr;
    logic [BUFFER_WIDTH-1:0][47:0]       wdata;
  } buffer_reg_in_type;

  typedef struct packed {logic [BUFFER_WIDTH-1:0][47:0] rdata;} buffer_reg_out_type;

endpackage

import configure::*;
import constants::*;
import wires::*;
import buffer_wires::*;

module buffer_reg (
  input  logic               clock,
  input  buffer_reg_in_type  buffer_reg_in,
  output buffer_reg_out_type buffer_reg_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam BDEPTH = $clog2(BUFFER_DEPTH);
  localparam BWIDTH = $clog2(BUFFER_WIDTH);

  genvar i;

  generate
    for (i = 0; i < BUFFER_WIDTH; i++) begin : gen_buffer_reg_array
      logic [47:0] buffer_reg_array[0:BUFFER_DEPTH-1] = '{default: '0};
      always_ff @(posedge clock) begin
        if (buffer_reg_in.wen[i] == 1) begin
          buffer_reg_array[buffer_reg_in.waddr[i]] <= buffer_reg_in.wdata[i];
        end
      end
      always_ff @(posedge clock) begin
        if (buffer_reg_in.wen[i] == 1 && buffer_reg_in.raddr[i] == buffer_reg_in.waddr[i]) begin
          buffer_reg_out.rdata[i] <= buffer_reg_in.wdata[i];
        end else begin
          buffer_reg_out.rdata[i] <= buffer_reg_array[buffer_reg_in.raddr[i]];
        end
      end
    end
  endgenerate

endmodule

module buffer_ctrl (
  input  logic               reset,
  input  logic               clock,
  input  buffer_in_type      buffer_in,
  output buffer_out_type     buffer_out,
  input  buffer_reg_out_type buffer_reg_out,
  output buffer_reg_in_type  buffer_reg_in
);
  timeunit 1ns; timeprecision 1ps;

  localparam BDEPTH = $clog2(BUFFER_DEPTH);
  localparam BWIDTH = $clog2(BUFFER_WIDTH);
  localparam W = BDEPTH + BWIDTH;
  localparam TOTAL = BUFFER_WIDTH * (BUFFER_DEPTH - 2);

  localparam WINDOW = 2 * ISSUE_WIDTH;

  typedef struct packed {
    logic [BUFFER_WIDTH-1:0][47:0] wdata;
    logic [W-1:0]                  wid;
    logic [0:0]                    wen;
    logic [BDEPTH-1:0]             wid_row;
    logic [W-1:0]                  rid;
    logic [BWIDTH-1:0]             rid_bank;
    logic [BDEPTH-1:0]             rid_row;
    logic [BDEPTH-1:0]             rid_row_p1;
  } front_reg_type;

  parameter front_reg_type init_front_reg = '{
      wdata : '{default: '0},
      wid : 0,
      wen : 0,
      wid_row : 0,
      rid : 0,
      rid_bank : 0,
      rid_row : 0,
      rid_row_p1 : 0
  };

  typedef struct packed {
    logic [WINDOW-1:0][47:0]      rdata;
    logic [WINDOW-1:0]            comp;
    logic [W-1:0]                 diff;
    logic [W-1:0]                 count;
    logic [W-1:0]                 align;
    logic [ISSUE_WIDTH-1:0][31:0] pc;
    logic [ISSUE_WIDTH-1:0][31:0] instr;
    logic [ISSUE_WIDTH-1:0]       ready;
    logic [0:0]                   clear;
    logic [0:0]                   stall;
  } back_reg_type;

  parameter back_reg_type init_back_reg = '{
      rdata : '{default: '0},
      comp : 0,
      diff : 0,
      count : 0,
      align : 0,
      pc : '{default: '0},
      instr : '{default: '0},
      ready : 0,
      clear : 0,
      stall : 0
  };

  front_reg_type front_r, front_rin, front_v;
  back_reg_type back_r, back_rin, back_v;

  function automatic int slot_offset(input logic [WINDOW-1:0] comp, input int slot);
    int off;
    off = 0;
    for (int k = 0; k < slot; k++) begin
      off = off + (comp[off] ? 1 : 2);
    end
    return off;
  endfunction

  int base, need;

  always_comb begin : front_end

    front_v = front_r;

    if (buffer_in.clear == 1) begin
      front_v.wid = 0;
      front_v.rid = 0;
    end

    if (back_r.clear == 1 && buffer_in.clear == 0 && buffer_in.ready == 1) begin
      front_v.rid = {{W - BWIDTH{1'b0}}, buffer_in.pc[BWIDTH:1]};
    end

    front_v.wen = (~buffer_in.clear) & (~back_r.stall) & buffer_in.ready;

    front_v.wid_row = front_v.wid[W-1:BWIDTH];

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      front_v.wdata[k] = {
        buffer_in.pc[31:BWIDTH+1], k[BWIDTH-1:0], 1'b0, buffer_in.rdata[k*16+:16]
      };
    end

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      buffer_reg_in.wen[k]   = front_v.wen;
      buffer_reg_in.waddr[k] = front_v.wid_row;
      buffer_reg_in.wdata[k] = front_v.wdata[k];
    end

    if (front_v.wen == 1) begin
      front_v.wid = front_v.wid + BUFFER_WIDTH;
    end

    front_v.rid_bank   = front_v.rid[BWIDTH-1:0];
    front_v.rid_row    = front_v.rid[W-1:BWIDTH];
    front_v.rid_row_p1 = front_v.rid_row + 1'b1;

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      buffer_reg_in.raddr[k] = (k < int'(front_v.rid_bank)) ? front_v.rid_row_p1 : front_v.rid_row;
    end

    front_v.rid = front_v.rid + back_v.diff;

    front_rin = front_v;

    buffer_out.stall = ~front_v.wen;

  end

  always_comb begin : back_end

    back_v = back_r;

    if (buffer_in.clear == 1) begin
      back_v.count = 0;
      back_v.clear = 1;
    end

    if (back_r.clear == 1 && buffer_in.clear == 0 && buffer_in.ready == 1) begin
      back_v.align = {{W - BWIDTH{1'b0}}, buffer_in.pc[BWIDTH:1]};
      back_v.clear = 0;
    end

    for (int j = 0; j < WINDOW; j++) begin
      back_v.rdata[j] = buffer_reg_out.rdata[(int'(front_r.rid_bank)+j)&(BUFFER_WIDTH-1)];
    end

    if (front_v.wen == 1) begin
      back_v.count = back_v.count + BUFFER_WIDTH;
    end

    back_v.diff = 0;

    for (int k = 0; k < WINDOW; k++) begin
      back_v.comp[k] = ~(&back_v.rdata[k][1:0]);
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      back_v.pc[s]    = '0;
      back_v.instr[s] = '0;
      back_v.ready[s] = 0;
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      base = slot_offset(back_v.comp, s);
      need = back_v.comp[base] ? 1 : 2;
      if (back_v.count > back_v.align + W'(base) + (back_v.comp[base] ? W'(0) : W'(1))) begin
        back_v.pc[s] = back_v.rdata[base][47:16];
        if (back_v.comp[base]) begin
          back_v.instr[s] = {16'b0, back_v.rdata[base][15:0]};
        end else begin
          back_v.instr[s] = {back_v.rdata[base+1][15:0], back_v.rdata[base][15:0]};
        end
        back_v.ready[s] = 1;
        back_v.diff     = W'(base) + W'(need);
      end
    end

    if (buffer_in.stall == 1) begin
      back_v.diff  = 0;
      back_v.ready = '0;
    end

    back_v.count = back_v.count - back_v.diff;

    if (back_v.count > TOTAL) begin
      back_v.stall = 1;
    end else begin
      back_v.stall = 0;
    end

    back_rin = back_v;

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      buffer_out.pc[s]    = back_v.ready[s] ? back_v.pc[s] : 32'hFFFFFFFF;
      buffer_out.instr[s] = back_v.ready[s] ? back_v.instr[s] : 0;
      buffer_out.ready[s] = back_v.ready[s];
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      front_r <= init_front_reg;
      back_r  <= init_back_reg;
    end else begin
      front_r <= front_rin;
      back_r  <= back_rin;
    end
  end

endmodule

module buffer (
  input  logic           reset,
  input  logic           clock,
  input  buffer_in_type  buffer_in,
  output buffer_out_type buffer_out
);
  timeunit 1ns; timeprecision 1ps;

  buffer_reg_in_type  buffer_reg_in;
  buffer_reg_out_type buffer_reg_out;

  buffer_reg buffer_reg_comp (
    .clock         (clock),
    .buffer_reg_in (buffer_reg_in),
    .buffer_reg_out(buffer_reg_out)
  );

  buffer_ctrl buffer_ctrl_comp (
    .reset         (reset),
    .clock         (clock),
    .buffer_in     (buffer_in),
    .buffer_out    (buffer_out),
    .buffer_reg_in (buffer_reg_in),
    .buffer_reg_out(buffer_reg_out)
  );

endmodule
