// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module uartdpi #(
  parameter BAUD = 'x,
  parameter FREQ = 'x,
  parameter string NAME = "uart0"
)(
  input  logic clk_i,
  input  logic rst_ni,

  output logic tx_o,
  input  logic rx_i
);

  localparam int CYCLES_PER_SYMBOL = FREQ / BAUD;

  import "DPI-C" function
    chandle uartdpi_create(input string name);

  import "DPI-C" function
    void uartdpi_close(input chandle ctx);

  import "DPI-C" function
    byte uartdpi_read(input chandle ctx);

  import "DPI-C" function
    int uartdpi_can_read(input chandle ctx);

  import "DPI-C" function
    void uartdpi_write(input chandle ctx, int data);

  chandle ctx;
  int file_handle;
  string file_name;

  initial begin
    ctx = uartdpi_create(NAME);
    $sformat(file_name, "%s.log", NAME);
    file_handle = $fopen(file_name, "w");
  end

  final begin
    uartdpi_close(ctx);
    ctx = 0;
  end

  // TX
  reg txactive;
  int  txcount;
  int  txcyccount;
  reg [9:0] txsymbol;

  always_ff @(negedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tx_o <= 1;
      txactive <= 0;
    end else begin
      if (!txactive) begin
        tx_o <= 1;
        if (uartdpi_can_read(ctx)) begin
          automatic int c = uartdpi_read(ctx);
          txsymbol <= {1'b1, c[7:0], 1'b0};
          txactive <= 1;
          txcount <= 0;
          txcyccount <= 0;
        end
      end else begin
        txcyccount <= txcyccount + 1;
        tx_o <= txsymbol[txcount];
        if (txcyccount == CYCLES_PER_SYMBOL) begin
          txcyccount <= 0;
          if (txcount == 9)
            txactive <= 0;
          else
            txcount <= txcount + 1;
        end
      end
    end
  end

  // RX
  reg rxactive;
  int rxcount;
  int rxcyccount;
  reg [7:0] rxsymbol;

  always_ff @(negedge clk_i or negedge rst_ni) begin
    rxcyccount <= rxcyccount + 1;

    if (!rst_ni) begin
      rxactive <= 0;
    end else begin
      if (!rxactive) begin
        if (!rx_i) begin
          rxactive <= 1;
          rxcount <= 0;
          rxcyccount <= 0;
        end
      end else begin
        if (rxcount == 0) begin
          if (rxcyccount == CYCLES_PER_SYMBOL/2) begin
            if (rx_i) begin
              rxactive <= 0;
            end else begin
              rxcount <= rxcount + 1;
              rxcyccount <= 0;
            end
          end
        end else if (rxcount <= 8) begin
          if (rxcyccount == CYCLES_PER_SYMBOL) begin
            rxsymbol[rxcount-1] <= rx_i;
            rxcount <= rxcount + 1;
            rxcyccount <= 0;
          end
        end else begin
          if (rxcyccount == CYCLES_PER_SYMBOL) begin
            rxactive <= 0;
            if (rx_i) begin
              uartdpi_write(ctx, rxsymbol);
              $fwrite(file_handle, "%c", rxsymbol);
            end
          end
        end
      end
    end
  end

endmodule
