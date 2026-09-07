package buffer_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam BDEPTH = $clog2(BUFFER_DEPTH);
  localparam BWIDTH = $clog2(BUFFER_WIDTH);

  typedef struct packed {
    logic [BUFFER_WIDTH-1:0][0:0]        wen;
    logic [BUFFER_WIDTH-1:0][BDEPTH-1:0] waddr;
    logic [BUFFER_WIDTH-1:0][BDEPTH-1:0] raddr;
    logic [BUFFER_WIDTH-1:0][15:0]       wdata;
  } buffer_reg_in_type;

  typedef struct packed {logic [BUFFER_WIDTH-1:0][15:0] rdata;} buffer_reg_out_type;

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
      logic [15:0] buffer_reg_array[0:BUFFER_DEPTH-1] = '{default: '0};
      always_ff @(posedge clock) begin
        if (buffer_reg_in.wen[i] == 1) begin
          buffer_reg_array[buffer_reg_in.waddr[i]] <= buffer_reg_in.wdata[i];
        end
      end
      always_comb begin
        buffer_reg_out.rdata[i] = (buffer_reg_in.wen[i] == 1 && buffer_reg_in.raddr[i] == buffer_reg_in.waddr[i]) ?
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

  localparam BDEPTH = $clog2(BUFFER_DEPTH);
  localparam BWIDTH = $clog2(BUFFER_WIDTH);
  localparam W      = BDEPTH + BWIDTH;
  localparam TOTAL  = BUFFER_WIDTH * (BUFFER_DEPTH - 2);

  localparam WINDOW = 2 * ISSUE_WIDTH;

  localparam [W-1:0] one = 1;

  typedef struct packed {
    logic [BUFFER_WIDTH-1:0][15:0]      wdata;
    logic [WINDOW-1:0][15:0]            rdata;
    logic [WINDOW-1:0]                  comp;
    logic [ISSUE_WIDTH-1:0][WINDOW-1:0] sel_pos;
    logic [ISSUE_WIDTH-1:0][W-1:0]      base_off;
    logic [ISSUE_WIDTH-1:0][3:0]        need_idx;
    logic [ISSUE_WIDTH-1:0][3:0]        step;
    logic [W:0]                         avail;
    logic [ISSUE_WIDTH-1:0]             base_comp;
    logic [ISSUE_WIDTH-1:0][15:0]       sel_lo;
    logic [ISSUE_WIDTH-1:0][15:0]       sel_hi;
    logic [W-1:0]                       wid;
    logic [W-1:0]                       rid;
    logic [31:0]                        pc_base;
    logic [W-1:0]                       diff;
    logic [W-1:0]                       count;
    logic [W-1:0]                       align;
    logic [ISSUE_WIDTH-1:0][31:0]       pc;
    logic [ISSUE_WIDTH-1:0][31:0]       instr;
    logic [ISSUE_WIDTH-1:0]             ready;
    logic [0:0]                         wen;
    logic [0:0]                         flush;
    logic [0:0]                         stall;
    logic [BWIDTH-1:0]                  rid_bank;
    logic [BDEPTH-1:0]                  rid_row;
    logic [BDEPTH-1:0]                  rid_row_p1;
    logic [BDEPTH-1:0]                  wid_row;
  } reg_type;

  parameter reg_type init_reg = '{
      wdata : '{default: '0},
      rdata : '{default: '0},
      comp : 0,
      sel_pos : '{default: '0},
      base_off : '{default: '0},
      need_idx : '{default: '0},
      step : '{default: '0},
      avail : 0,
      base_comp : 0,
      sel_lo : '{default: '0},
      sel_hi : '{default: '0},
      wid : 0,
      rid : 0,
      pc_base : 0,
      diff : 0,
      count : 0,
      align : 0,
      pc : '{default: '0},
      instr : '{default: '0},
      ready : 0,
      wen : 0,
      flush : 0,
      stall : 0,
      rid_bank : 0,
      rid_row : 0,
      rid_row_p1 : 0,
      wid_row : 0
  };

  reg_type r, rin, v;

  always_comb begin

    v = r;

    if (buffer_in.flush == 1) begin
      v.wid   = 0;
      v.rid   = 0;
      v.count = 0;
      v.flush = 1;
    end

    if (r.flush == 1 && buffer_in.flush == 0 && buffer_in.ready == 1) begin
      v.rid     = {{W - BWIDTH{1'b0}}, buffer_in.pc[BWIDTH:1]};
      v.align   = {{W - BWIDTH{1'b0}}, buffer_in.pc[BWIDTH:1]};
      v.pc_base = {buffer_in.pc[31:1], 1'b0};
      v.flush   = 0;
    end

    v.wen = (~buffer_in.flush) & (~r.stall) & buffer_in.ready;

    v.wid_row = v.wid[W-1:BWIDTH];

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      v.wdata[k] = buffer_in.rdata[k*16+:16];
    end

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      buffer_reg_in.wen[k]   = v.wen;
      buffer_reg_in.waddr[k] = v.wid_row;
      buffer_reg_in.wdata[k] = v.wdata[k];
    end

    v.rid_bank   = v.rid[BWIDTH-1:0];
    v.rid_row    = v.rid[W-1:BWIDTH];
    v.rid_row_p1 = v.rid_row + 1'b1;

    for (int k = 0; k < BUFFER_WIDTH; k++) begin
      buffer_reg_in.raddr[k] = (k < int'(v.rid_bank)) ? v.rid_row_p1 : v.rid_row;
    end

    for (int j = 0; j < WINDOW; j++) begin
      v.rdata[j] = buffer_reg_out.rdata[(int'(v.rid_bank)+j)&(BUFFER_WIDTH-1)];
    end

    if (v.wen == 1) begin
      v.wid   = v.wid + BUFFER_WIDTH;
      v.count = v.count + BUFFER_WIDTH;
    end

    v.diff = 0;

    for (int k = 0; k < WINDOW; k++) begin
      v.comp[k] = ~(&v.rdata[k][1:0]);
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      v.pc[s]    = '0;
      v.instr[s] = '0;
      v.ready[s] = 0;
    end

    v.sel_pos[0] = WINDOW'(1);
    for (int s = 1; s < ISSUE_WIDTH; s++) begin
      v.sel_pos[s] = '0;
      for (int k = 0; k < WINDOW; k++) begin
        if (v.sel_pos[s-1][k] && v.comp[k] && (k + 1 < WINDOW)) begin
          v.sel_pos[s][k+1] = 1'b1;
        end
        if (v.sel_pos[s-1][k] && !v.comp[k] && (k + 2 < WINDOW)) begin
          v.sel_pos[s][k+2] = 1'b1;
        end
      end
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      v.base_off[s]  = '0;
      v.base_comp[s] = 1'b0;
      v.need_idx[s]  = 4'h0;
      v.step[s]      = 4'h1;
      v.sel_lo[s]    = 16'h0;
      v.sel_hi[s]    = 16'h0;
      for (int k = 0; k < WINDOW; k++) begin
        if (v.sel_pos[s][k]) begin
          v.base_off[s]  = W'(unsigned'(k));
          v.base_comp[s] = v.comp[k];
          v.need_idx[s]  = v.comp[k] ? 4'(unsigned'(k)) : 4'(unsigned'(k + 1));
          v.step[s]      = v.comp[k] ? 4'(unsigned'(k + 1)) : 4'(unsigned'(k + 2));
          v.sel_lo[s]    = v.rdata[k];
          v.sel_hi[s]    = (k + 1 < WINDOW) ? v.rdata[(k+1)&(WINDOW-1)] : 16'h0;
        end
      end
    end

    v.avail = {1'b0, v.count} - {1'b0, v.align};

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
      if (!v.avail[W] && (v.avail[W-1:0] > W'(v.need_idx[s]))) begin
        v.pc[s]    = v.pc_base + (32'(v.base_off[s]) << 1);
        v.instr[s] = v.base_comp[s] ? {16'b0, v.sel_lo[s]} : {v.sel_hi[s], v.sel_lo[s]};
        v.ready[s] = 1;
        v.diff     = W'(v.step[s]);
      end
    end

    if (buffer_in.stall == 1) begin
      v.diff  = 0;
      v.ready = '0;
    end

    v.count   = v.count - v.diff;
    v.rid     = v.rid + v.diff;
    v.pc_base = v.pc_base + (32'(v.diff) << 1);

    if (v.count > TOTAL) begin
      v.stall = 1;
    end
    else begin
      v.stall = 0;
    end

    for (int s = 0; s < ISSUE_WIDTH; s++) begin
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
    end
    else begin
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
