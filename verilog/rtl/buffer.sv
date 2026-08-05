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
    logic [W-1:0]                  count;
    logic [W-1:0]                  align;
    logic [W-1:0]                  wid;
    logic [0:0]                    wen;
    logic [BDEPTH-1:0]             wid_row;
    logic [W-1:0]                  rid;
    logic [BWIDTH-1:0]             rid_bank;
    logic [BDEPTH-1:0]             rid_row;
    logic [BDEPTH-1:0]             rid_row_p1;
    logic [0:0]                    clear;
  } reg_front_type;

  parameter reg_front_type init_reg_front = '{
      wdata : '{default: '0},
      count : 0,
      align : 0,
      wid : 0,
      wen : 0,
      wid_row : 0,
      rid : 0,
      rid_bank : 0,
      rid_row : 0,
      rid_row_p1 : 0,
      clear : 0
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
    logic [0:0]                   wen;
    logic [W-1:0]                 rid;
    logic [BWIDTH-1:0]            rid_bank;
    logic [BDEPTH-1:0]            rid_row;
    logic [BDEPTH-1:0]            rid_row_p1;
    logic [0:0]                   clear;
    logic [0:0]                   stall;
  } reg_back_type;

  parameter reg_back_type init_reg_back = '{
      rdata : '{default: '0},
      comp : 0,
      diff : 0,
      count : 0,
      align : 0,
      pc : '{default: '0},
      instr : '{default: '0},
      ready : 0,
      wen : 0,
      rid : 0,
      rid_bank : 0,
      rid_row : 0,
      rid_row_p1 : 0,
      clear : 0,
      stall : 0
  };

  reg_front_type r_front, rin_front, v_front;
  reg_back_type r_back, rin_back, v_back;

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

    v_front = r_front;

    v_front.rid = v_back.rid;

    if (buffer_in.clear == 1) begin
      v_front.wid   = 0;
      v_front.rid   = 0;
      v_front.count = 0;
      v_front.clear = 1;
    end

    if (r_front.clear == 1 && buffer_in.clear == 0 && buffer_in.ready == 1) begin
      v_front.rid   = {{W - BWIDTH{1'b0}}, buffer_in.pc[BWIDTH:1]};
      v_front.align = {{W - BWIDTH{1'b0}}, buffer_in.pc[BWIDTH:1]};
      v_front.clear = 0;
    end

    v_front.wen = (~buffer_in.clear) & (~r_back.stall) & buffer_in.ready;

    v_front.wid_row = v_front.wid[W-1:BWIDTH];

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      v_front.wdata[k] = {
        buffer_in.pc[31:BWIDTH+1], k[BWIDTH-1:0], 1'b0, buffer_in.rdata[k*16+:16]
      };
    end

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      buffer_reg_in.wen[k]   = v_front.wen;
      buffer_reg_in.waddr[k] = v_front.wid_row;
      buffer_reg_in.wdata[k] = v_front.wdata[k];
    end

    if (v_front.wen == 1) begin
      v_front.wid   = v_front.wid + BUFFER_WIDTH;
      v_front.count = v_front.count + BUFFER_WIDTH;
    end

    v_front.rid_bank   = v_front.rid[BWIDTH-1:0];
    v_front.rid_row    = v_front.rid[W-1:BWIDTH];
    v_front.rid_row_p1 = v_front.rid_row + 1'b1;

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      buffer_reg_in.raddr[k] = (k < int'(v_front.rid_bank)) ? v_front.rid_row_p1 : v_front.rid_row;
    end

    rin_front = v_front;

    buffer_out.stall = ~v_front.wen;

  end

  always_comb begin : back_end

    v_back = r_back;

    v_back.wen = r_front.wen;

    v_back.count = r_front.count;
    v_back.align = r_front.align;

    v_back.rid        = r_front.rid;
    v_back.rid_bank   = r_front.rid_bank;
    v_back.rid_row    = r_front.rid_row;
    v_back.rid_row_p1 = r_front.rid_row_p1;

    for (int j = 0; j < WINDOW; j++) begin
      v_back.rdata[j] = buffer_reg_out.rdata[(int'(v_back.rid_bank)+j)&(BUFFER_WIDTH-1)];
    end

    if (v_back.wen == 1) begin
      v_back.count = v_back.count + BUFFER_WIDTH;
    end

    v_back.diff = 0;

    for (int k = 0; k < WINDOW; k++) begin
      v_back.comp[k] = ~(&v_back.rdata[k][1:0]);
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      v_back.pc[s]    = '0;
      v_back.instr[s] = '0;
      v_back.ready[s] = 0;
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      base = slot_offset(v_back.comp, s);
      need = v_back.comp[base] ? 1 : 2;
      if (v_back.count > v_back.align + W'(base) + (v_back.comp[base] ? W'(0) : W'(1))) begin
        v_back.pc[s] = v_back.rdata[base][47:16];
        if (v_back.comp[base]) begin
          v_back.instr[s] = {16'b0, v_back.rdata[base][15:0]};
        end else begin
          v_back.instr[s] = {v_back.rdata[base+1][15:0], v_back.rdata[base][15:0]};
        end
        v_back.ready[s] = 1;
        v_back.diff     = W'(base) + W'(need);
      end
    end

    if (buffer_in.stall == 1) begin
      v_back.diff  = 0;
      v_back.ready = '0;
    end

    v_back.count = v_back.count - v_back.diff;
    v_back.rid   = v_back.rid + v_back.diff;

    if (v_back.count > TOTAL) begin
      v_back.stall = 1;
    end else begin
      v_back.stall = 0;
    end

    rin_back = v_back;

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      buffer_out.pc[s]    = v_back.ready[s] ? v_back.pc[s] : 32'hFFFFFFFF;
      buffer_out.instr[s] = v_back.ready[s] ? v_back.instr[s] : 0;
      buffer_out.ready[s] = v_back.ready[s];
    end

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r_front <= init_reg_front;
      r_back  <= init_reg_back;
    end else begin
      r_front <= rin_front;
      r_back  <= rin_back;
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
