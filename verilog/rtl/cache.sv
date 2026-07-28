package cache_wires;
  timeunit 1ns; timeprecision 1ps;

  import configure::*;

  localparam CDEPTH = $clog2(CACHE_DEPTH);
  localparam CWIDTH = $clog2(CACHE_WIDTH);
  localparam CTAG = 32 - CDEPTH - CWIDTH - 2;

  typedef struct packed {
    logic [CDEPTH-1:0] addr;
    logic [31:0]       data;
    logic [0:0]        error;
    logic [0:0]        wren;
  } cache_ram_in_type;

  typedef struct packed {
    logic [31:0] data;
    logic [0:0]  error;
  } cache_ram_out_type;

  typedef struct packed {
    logic [CDEPTH-1:0] raddr;
    logic [CDEPTH-1:0] waddr;
    logic [0:0]        wren;
    logic [CTAG-1:0]   wtag;
    logic [0:0]        wvalid;
  } cache_tag_in_type;

  typedef struct packed {
    logic [CTAG-1:0] rtag;
    logic [0:0]      rvalid;
  } cache_tag_out_type;

  typedef cache_ram_in_type cache_vec_in_type[CACHE_WIDTH];
  typedef cache_ram_out_type cache_vec_out_type[CACHE_WIDTH];

  localparam cache_vec_in_type init_cache_vec_in = '{default: '0};
  localparam cache_vec_out_type init_cache_vec_out = '{default: '0};
  localparam cache_tag_in_type init_cache_tag_in = '{default: '0};
  localparam cache_tag_out_type init_cache_tag_out = '{default: '0};

endpackage

import configure::*;
import wires::*;
import cache_wires::*;

module cache_ram (
  input  logic              clock,
  input  cache_ram_in_type  cache_ram_in,
  output cache_ram_out_type cache_ram_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam CDEPTH = $clog2(CACHE_DEPTH);

  logic [32:0] ram[0:CACHE_DEPTH-1];

  always_ff @(posedge clock) begin
    if (cache_ram_in.wren == 1) begin
      ram[cache_ram_in.addr] <= {cache_ram_in.error, cache_ram_in.data};
    end
    {cache_ram_out.error, cache_ram_out.data} <= ram[cache_ram_in.addr];
  end

endmodule

module cache_tag_ram (
  input  logic              clock,
  input  cache_tag_in_type  cache_tag_in,
  output cache_tag_out_type cache_tag_out
);
  timeunit 1ns; timeprecision 1ps;

  localparam CDEPTH = $clog2(CACHE_DEPTH);
  localparam CWIDTH = $clog2(CACHE_WIDTH);
  localparam CTAG = 32 - CDEPTH - CWIDTH - 2;

  logic [CTAG-1:0] tag_mem  [0:CACHE_DEPTH-1];
  logic [     0:0] valid_mem[0:CACHE_DEPTH-1];

  always_ff @(posedge clock) begin
    if (cache_tag_in.wren == 1) begin
      tag_mem[cache_tag_in.waddr]   <= cache_tag_in.wtag;
      valid_mem[cache_tag_in.waddr] <= cache_tag_in.wvalid;
    end
    cache_tag_out.rtag   <= tag_mem[cache_tag_in.raddr];
    cache_tag_out.rvalid <= valid_mem[cache_tag_in.raddr];
  end

endmodule

module cache_ctrl (
  input  logic              reset,
  input  logic              clock,
  input  cache_vec_out_type cache_vec_out,
  output cache_vec_in_type  cache_vec_in,
  input  cache_tag_out_type cache_tag_out,
  output cache_tag_in_type  cache_tag_in,
  input  cache_in_type      cache_in,
  output cache_out_type     cache_out,
  input  mem_out_type       mem_out      [0:1],
  output mem_in_type        mem_in       [0:1]
);
  timeunit 1ns; timeprecision 1ps;

  localparam CDEPTH = $clog2(CACHE_DEPTH);
  localparam CWIDTH = $clog2(CACHE_WIDTH);
  localparam CTAG = 32 - CDEPTH - CWIDTH - 2;

  typedef struct packed {
    logic [CTAG-1:0]   tag;
    logic [CDEPTH-1:0] idx;
    logic [0:0]        valid;
  } front_type;

  typedef enum logic [1:0] {
    HIT  = 2'd0,
    FILL = 2'd1,
    DONE = 2'd2
  } cache_state;

  typedef struct packed {
    cache_state                state;
    logic [CWIDTH-1:0]         fill_wid;
    logic [CTAG-1:0]           fill_tag;
    logic [CDEPTH-1:0]         fill_idx;
    logic [31:0]               fill_base;
    logic [31:0]               fill_data[0:1];
    logic [0:0]                fill_error[0:1];
    logic [1:0]                fill_wen;
    logic [0:0]                fill_tag_wen;
    logic [0:0]                mem_valid[0:1];
    logic [31:0]               mem_addr[0:1];
    logic [CACHE_WIDTH*32-1:0] rdata;
    logic [CACHE_WIDTH-1:0]    error;
    logic [0:0]                ready;
  } back_type;

  parameter front_type init_front = 0;
  parameter back_type init_back = 0;

  front_type r_f, rin_f;
  front_type v_f;

  back_type r_b, rin_b;
  back_type v_b;

  always_comb begin

    v_f = r_f;

    v_f.valid = 0;

    if (cache_in.mem_valid == 1 && r_b.state == HIT) begin
      v_f.valid = 1;
      v_f.tag   = cache_in.mem_addr[31:(CDEPTH+CWIDTH+2)];
      v_f.idx   = cache_in.mem_addr[(CDEPTH+CWIDTH+1):(CWIDTH+2)];
    end

    cache_vec_in = init_cache_vec_in;
    cache_tag_in = init_cache_tag_in;

    if (r_b.state == FILL) begin
      if (r_b.fill_wen[0] == 1) begin
        cache_vec_in[r_b.fill_wid].wren  = 1;
        cache_vec_in[r_b.fill_wid].addr  = r_b.fill_idx;
        cache_vec_in[r_b.fill_wid].data  = r_b.fill_data[0];
        cache_vec_in[r_b.fill_wid].error = r_b.fill_error[0];
      end
      if (r_b.fill_wen[1] == 1) begin
        cache_vec_in[r_b.fill_wid+1].wren  = 1;
        cache_vec_in[r_b.fill_wid+1].addr  = r_b.fill_idx;
        cache_vec_in[r_b.fill_wid+1].data  = r_b.fill_data[1];
        cache_vec_in[r_b.fill_wid+1].error = r_b.fill_error[1];
      end
      if (r_b.fill_tag_wen == 1) begin
        cache_tag_in.raddr  = r_b.fill_idx;
        cache_tag_in.wren   = 1;
        cache_tag_in.wvalid = 1;
        cache_tag_in.wtag   = r_b.fill_tag;
        cache_tag_in.waddr  = r_b.fill_idx;
      end
    end else begin
      if (v_f.valid == 1) begin
        for (int w = 0; w < CACHE_WIDTH; w++) begin
          cache_vec_in[w].addr = v_f.idx;
        end
      end
      cache_tag_in.raddr = v_f.idx;
    end

    rin_f = v_f;

  end

  always_comb begin

    v_b = r_b;

    v_b.ready        = 0;
    v_b.fill_wen     = 0;
    v_b.fill_tag_wen = 0;
    v_b.mem_valid[0] = 0;
    v_b.mem_valid[1] = 0;

    cache_out = init_cache_out;

    case (r_b.state)

      HIT: begin
        if (r_f.valid == 1) begin
          if (cache_tag_out.rvalid == 1 && cache_tag_out.rtag == r_f.tag) begin
            v_b.ready = 1;
            for (int w = 0; w < CACHE_WIDTH; w++) begin
              v_b.rdata[w*32+:32] = cache_vec_out[w].data;
              v_b.error[w]        = cache_vec_out[w].error;
            end
          end else begin
            v_b.state     = FILL;
            v_b.fill_wid  = 0;
            v_b.fill_tag  = r_f.tag;
            v_b.fill_idx  = r_f.idx;
            v_b.fill_base = {r_f.tag, r_f.idx, {CWIDTH{1'b0}}, 2'b00};
          end
        end
      end

      FILL: begin
        v_b.mem_valid[0] = 1;
        v_b.mem_addr[0]  = r_b.fill_base + {{(32 - CWIDTH) {1'b0}}, r_b.fill_wid, 2'b00};
        v_b.mem_valid[1] = 1;
        v_b.mem_addr[1]  = r_b.fill_base + {{(32 - CWIDTH) {1'b0}}, r_b.fill_wid + 1, 2'b00};
        if (mem_out[0].mem_ready == 1 && mem_out[1].mem_ready == 1) begin
          v_b.fill_wen[0]                    = 1;
          v_b.fill_data[0]                   = mem_out[0].mem_rdata;
          v_b.fill_error[0]                  = mem_out[0].mem_error;
          v_b.rdata[r_b.fill_wid*32+:32]     = mem_out[0].mem_rdata;
          v_b.error[r_b.fill_wid]            = mem_out[0].mem_error;
          v_b.fill_wen[1]                    = 1;
          v_b.fill_data[1]                   = mem_out[1].mem_rdata;
          v_b.fill_error[1]                  = mem_out[1].mem_error;
          v_b.rdata[(r_b.fill_wid+1)*32+:32] = mem_out[1].mem_rdata;
          v_b.error[r_b.fill_wid+1]          = mem_out[1].mem_error;
          if (r_b.fill_wid >= CACHE_WIDTH[CWIDTH:0] - 2) begin
            v_b.fill_tag_wen = 1;
            v_b.state        = DONE;
          end else begin
            v_b.fill_wid = r_b.fill_wid + 2;
          end
        end
      end

      DONE: begin
        v_b.ready = 1;
        v_b.state = HIT;
      end

      default: begin
        v_b.state = HIT;
      end

    endcase

    cache_out.mem_ready = v_b.ready;
    cache_out.mem_rdata = v_b.rdata;
    cache_out.mem_error = v_b.error;

    mem_in[0].mem_valid = v_b.mem_valid[0];
    mem_in[0].mem_instr = 1;
    mem_in[0].mem_mode  = 0;
    mem_in[0].mem_addr  = v_b.mem_addr[0];
    mem_in[0].mem_wstrb = 0;
    mem_in[0].mem_wdata = 0;

    mem_in[1].mem_valid = v_b.mem_valid[1];
    mem_in[1].mem_instr = 1;
    mem_in[1].mem_mode  = 0;
    mem_in[1].mem_addr  = v_b.mem_addr[1];
    mem_in[1].mem_wstrb = 0;
    mem_in[1].mem_wdata = 0;

    rin_b = v_b;

  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      r_f <= init_front;
      r_b <= init_back;
    end else begin
      r_f <= rin_f;
      r_b <= rin_b;
    end
  end

endmodule

module cache (
  input  logic          reset,
  input  logic          clock,
  input  cache_in_type  cache_in,
  output cache_out_type cache_out,
  input  mem_out_type   mem_out  [0:1],
  output mem_in_type    mem_in   [0:1]
);
  timeunit 1ns; timeprecision 1ps;

  cache_vec_in_type  cache_vec_in;
  cache_vec_out_type cache_vec_out;

  cache_tag_in_type  cache_tag_in;
  cache_tag_out_type cache_tag_out;

  generate

    genvar i;

    for (i = 0; i < CACHE_WIDTH; i = i + 1) begin : cache_ram_gen
      cache_ram cache_ram_comp (
        .clock        (clock),
        .cache_ram_in (cache_vec_in[i]),
        .cache_ram_out(cache_vec_out[i])
      );
    end

  endgenerate

  cache_tag_ram cache_tag_ram_comp (
    .clock        (clock),
    .cache_tag_in (cache_tag_in),
    .cache_tag_out(cache_tag_out)
  );

  cache_ctrl cache_ctrl_comp (
    .reset        (reset),
    .clock        (clock),
    .cache_vec_out(cache_vec_out),
    .cache_vec_in (cache_vec_in),
    .cache_tag_out(cache_tag_out),
    .cache_tag_in (cache_tag_in),
    .cache_in     (cache_in),
    .cache_out    (cache_out),
    .mem_in       (mem_in),
    .mem_out      (mem_out)
  );

endmodule
