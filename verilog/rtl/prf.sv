import configure::*;
import wires::*;
import functions::*;

module prf (
  input  logic        reset,
  input  logic        clock,
  input  prf_in_type  prf_in,
  output prf_out_type prf_out
);
  timeunit 1ns; timeprecision 1ps;

  typedef struct packed {
    logic [PRF_WPORTS-1:0][0:0]                  wen;
    logic [PRF_WPORTS-1:0][PRF_ADDR_BITS-1:0]    waddr;
    logic [PRF_WPORTS-1:0][31:0]                 wdata;
    logic [ISSUE_WIDTH-1:0][0:0]                 aen;
    logic [ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0]   aaddr;
    logic [2*ISSUE_WIDTH-1:0][PRF_ADDR_BITS-1:0] raddr;
    logic [2*ISSUE_WIDTH-1:0][31:0]              rdata;
    logic [2*ISSUE_WIDTH-1:0][0:0]               rready;
    logic [PRF_DEPTH-1:0]                        ready_next;
  } prf_reg_type;

  logic [         31:0] data  [0:PRF_DEPTH-1];
  logic [PRF_DEPTH-1:0] ready;

  prf_reg_type v;

  always_comb begin
    for (int w = 0; w < PRF_WPORTS; w++) begin
      v.wen[w]   = prf_in.wren[w] && (prf_in.waddr[w] != '0);
      v.waddr[w] = prf_in.waddr[w];
      v.wdata[w] = prf_in.wdata[w];
    end

    for (int a = 0; a < ISSUE_WIDTH; a++) begin
      v.aen[a]   = prf_in.aren[a] && (prf_in.aaddr[a] != '0);
      v.aaddr[a] = prf_in.aaddr[a];
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      v.raddr[i] = prf_in.raddr[i];
    end

    prf_out = init_prf_out;

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      v.rdata[i]  = data[v.raddr[i]];
      v.rready[i] = ready[v.raddr[i]];
      for (int w = 0; w < PRF_WPORTS; w++) begin
        if (v.wen[w] && (v.waddr[w] == v.raddr[i])) begin
          v.rdata[i]  = v.wdata[w];
          v.rready[i] = 1'b1;
        end
      end
      for (int a = 0; a < ISSUE_WIDTH; a++) begin
        if (v.aen[a] && (v.aaddr[a] == v.raddr[i])) begin
          v.rready[i] = 1'b0;
        end
      end
    end

    for (int i = 0; i < 2 * ISSUE_WIDTH; i++) begin
      prf_out.rdata[i]  = v.rdata[i];
      prf_out.rready[i] = v.rready[i];
    end

    v.ready_next = ready;
    for (int w = 0; w < PRF_WPORTS; w++) begin
      if (v.wen[w]) begin
        v.ready_next[v.waddr[w]] = 1'b1;
      end
    end
    for (int a = 0; a < ISSUE_WIDTH; a++) begin
      if (v.aen[a]) begin
        v.ready_next[v.aaddr[a]] = 1'b0;
      end
    end
  end

  always_ff @(posedge clock) begin
    if (reset == 0) begin
      for (int i = 0; i < PRF_DEPTH; i++) begin
        data[i]  <= '0;
        ready[i] <= (i < ARCH_REGS);
      end
    end
    else begin
      for (int w = 0; w < PRF_WPORTS; w++) begin
        if (v.wen[w]) begin
          data[v.waddr[w]] <= v.wdata[w];
        end
      end
      ready <= v.ready_next;
    end
  end

endmodule
