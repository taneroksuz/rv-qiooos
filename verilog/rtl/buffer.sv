package buffer_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam DEPTH = $clog2(BUFFER_DEPTH);

  typedef struct packed {
    logic [7:0][0 : 0]       wen;
    logic [7:0][DEPTH-1 : 0] waddr;
    logic [7:0][DEPTH-1 : 0] raddr;
    logic [7:0][47 : 0]      wdata;
  } buffer_reg_in_type;

  typedef struct packed {logic [7:0][47 : 0] rdata;} buffer_reg_out_type;

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

  localparam DEPTH = $clog2(BUFFER_DEPTH);

  genvar i;

  generate
    for (i = 0; i < 8; i++) begin : gen_buffer_reg_array
      logic [47:0] buffer_reg_array[0:BUFFER_DEPTH-1] = '{default: '0};
      always_ff @(posedge clock) begin
        if (buffer_reg_in.wen[i] == 1) begin
          buffer_reg_array[buffer_reg_in.waddr[i]] <= buffer_reg_in.wdata[i];
        end
      end
      always_comb begin
        buffer_reg_out.rdata[i] = (buffer_reg_in.wen[i] == 1 &&
                                   buffer_reg_in.raddr[i] == buffer_reg_in.waddr[i]) ?
            buffer_reg_in.wdata[i] : buffer_reg_array[buffer_reg_in.raddr[i]];
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

  localparam DEPTH = $clog2(BUFFER_DEPTH);
  localparam W = DEPTH + 3;
  localparam TOTAL = 8 * (BUFFER_DEPTH - 2);

  localparam [W-1:0] one = 1;

  typedef struct packed {
    logic [W-1 : 0]     wid;
    logic [W-1 : 0]     rid;
    logic [W-1 : 0]     diff;
    logic [W-1 : 0]     count;
    logic [W-1 : 0]     align;
    logic [7:0][47 : 0] wdata;
    logic [7:0][47 : 0] rdata;
    logic [3:0][31 : 0] pc;
    logic [3:0][31 : 0] instr;
    logic [7 : 0]       comp;
    logic [3 : 0]       ready;
    logic [0 : 0]       wen;
    logic [0 : 0]       clear;
    logic [0 : 0]       stall;
  } reg_type;

  parameter reg_type init_reg = '{
      wid : 0,
      rid : 0,
      diff : 0,
      count : 0,
      align : 0,
      wdata : '{default: '0},
      rdata : '{default: '0},
      pc : '{default: '0},
      instr : '{default: '0},
      comp : 0,
      ready : 0,
      wen : 0,
      clear : 0,
      stall : 0
  };

  reg_type r, rin, v;

  function automatic int slot_offset(input logic [7:0] comp, input int slot);
    int off;
    off = 0;
    for (int k = 0; k < slot; k++) begin
      off = off + (comp[off] ? 1 : 2);
    end
    return off;
  endfunction

  int base, need;

  logic [2:0] rid_bank;
  logic [DEPTH-1:0] rid_row, rid_row_p1;
  logic [DEPTH-1:0] wid_row;

  always_comb begin

    v = r;

    if (buffer_in.clear == 1) begin
      v.wid   = 0;
      v.rid   = 0;
      v.count = 0;
      v.clear = 1;
    end

    if (r.clear == 1 && buffer_in.clear == 0 && buffer_in.ready == 1) begin
      v.rid   = {{W - 1{1'b0}}, buffer_in.pc[0][1]};
      v.align = {{W - 1{1'b0}}, buffer_in.pc[0][1]};
      v.clear = 0;
    end

    v.wen = (~buffer_in.clear) & (~r.stall) & buffer_in.ready;

    v.wdata[0] = {buffer_in.pc[0][31:2], 2'b00, buffer_in.rdata[15:0]};
    v.wdata[1] = {buffer_in.pc[0][31:2], 2'b10, buffer_in.rdata[31:16]};
    v.wdata[2] = {buffer_in.pc[1][31:2], 2'b00, buffer_in.rdata[47:32]};
    v.wdata[3] = {buffer_in.pc[1][31:2], 2'b10, buffer_in.rdata[63:48]};

    wid_row = v.wid[W-1:3];

    for (int k = 0; k < 8; k++) begin
      buffer_reg_in.wen[k]   = 1'b0;
      buffer_reg_in.waddr[k] = '0;
      buffer_reg_in.wdata[k] = '0;
    end

    if (v.wid[2] == 1'b0) begin
      buffer_reg_in.wen[0]   = v.wen;
      buffer_reg_in.wen[1]   = v.wen;
      buffer_reg_in.wen[2]   = v.wen;
      buffer_reg_in.wen[3]   = v.wen;
      buffer_reg_in.waddr[0] = wid_row;
      buffer_reg_in.waddr[1] = wid_row;
      buffer_reg_in.waddr[2] = wid_row;
      buffer_reg_in.waddr[3] = wid_row;
      buffer_reg_in.wdata[0] = v.wdata[0];
      buffer_reg_in.wdata[1] = v.wdata[1];
      buffer_reg_in.wdata[2] = v.wdata[2];
      buffer_reg_in.wdata[3] = v.wdata[3];
    end else begin
      buffer_reg_in.wen[4]   = v.wen;
      buffer_reg_in.wen[5]   = v.wen;
      buffer_reg_in.wen[6]   = v.wen;
      buffer_reg_in.wen[7]   = v.wen;
      buffer_reg_in.waddr[4] = wid_row;
      buffer_reg_in.waddr[5] = wid_row;
      buffer_reg_in.waddr[6] = wid_row;
      buffer_reg_in.waddr[7] = wid_row;
      buffer_reg_in.wdata[4] = v.wdata[0];
      buffer_reg_in.wdata[5] = v.wdata[1];
      buffer_reg_in.wdata[6] = v.wdata[2];
      buffer_reg_in.wdata[7] = v.wdata[3];
    end

    rid_bank   = v.rid[2:0];
    rid_row    = v.rid[W-1:3];
    rid_row_p1 = rid_row + 1'b1;

    for (int k = 0; k < 8; k++) begin
      buffer_reg_in.raddr[k] = (k < int'(rid_bank)) ? rid_row_p1 : rid_row;
    end

    for (int j = 0; j < 8; j++) begin
      v.rdata[j] = buffer_reg_out.rdata[(int'(rid_bank)+j)%8];
    end

    if (v.wen == 1) begin
      v.wid   = v.wid + 4;
      v.count = v.count + 4;
    end

    v.diff = 0;

    for (int k = 0; k < 8; k++) begin
      v.comp[k] = ~(&v.rdata[k][1:0]);
    end

    for (int s = 0; s < 4; s++) begin
      v.pc[s]    = '0;
      v.instr[s] = '0;
      v.ready[s] = 0;
    end

    for (int s = 0; s < 4; s++) begin
      base = slot_offset(v.comp, s);
      need = v.comp[base] ? 1 : 2;
      if (v.count > v.align + W'(base) + (v.comp[base] ? W'(0) : W'(1))) begin
        v.pc[s] = v.rdata[base][47:16];
        if (v.comp[base]) begin
          v.instr[s] = {16'b0, v.rdata[base][15:0]};
        end else begin
          v.instr[s] = {v.rdata[base+1][15:0], v.rdata[base][15:0]};
        end
        v.ready[s] = 1;
        v.diff     = W'(base) + W'(need);
      end
    end

    if (buffer_in.stall == 1) begin
      v.diff  = 0;
      v.ready = '0;
    end

    v.count = v.count - v.diff;
    v.rid   = v.rid + v.diff;

    if (v.count > TOTAL) begin
      v.stall = 1;
    end else begin
      v.stall = 0;
    end

    for (int s = 0; s < 4; s++) begin
      buffer_out.pc[s]    = v.ready[s] ? v.pc[s] : 32'hFFFFFFFF;
      buffer_out.instr[s] = v.ready[s] ? v.instr[s] : 0;
      buffer_out.ready[s] = v.ready[s];
    end
    buffer_out.stall = ~v.wen;

    rin = v;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r <= init_reg;
    end else begin
      r <= rin;
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
