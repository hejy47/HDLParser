import dii_package::dii_flit;

module debug_system
  (
   input         clk, rstn,
   
   input         rx,
   output        tx,

   output        uart_irq,

   input [12:0]  uart_ar_addr,
   input         uart_ar_valid,
   output        uart_ar_ready,
    
   output [1:0]  uart_r_resp,
   output [31:0] uart_r_data,
   output        uart_r_valid,
   input         uart_r_ready,

   input [12:0]  uart_aw_addr,
   input         uart_aw_valid,
   output        uart_aw_ready,

   input [31:0]  uart_w_data,
   input         uart_w_valid,
   output        uart_w_ready,

   output [1:0]  uart_b_resp,
   output        uart_b_valid,
   input         uart_b_ready
   );

   logic  rst;
   assign rst = ~rstn;

   assign uart_irq = 0;
   
   logic [15:0]  fifo_out_data;
   logic         fifo_out_valid;
   logic         fifo_out_ready;
   logic  [15:0] fifo_in_data;
   logic         fifo_in_valid;
   logic         fifo_in_ready;

   logic  logic_rst, com_rst;
 
   glip_uart_toplevel
     #(.WIDTH(16), .BAUD(1000000), .FREQ(25000000))
   u_glip(.clk_io    (clk),
          .clk_logic (clk),
          .rst       (rst),
          .logic_rst (logic_rst),
          .com_rst   (com_rst),
          .fifo_in_data  (fifo_in_data[15:0]),
          .fifo_in_valid (fifo_in_valid),
          .fifo_in_ready (fifo_in_ready),
          .fifo_out_data  (fifo_out_data[15:0]),
          .fifo_out_valid (fifo_out_valid),
          .fifo_out_ready (fifo_out_ready),
          .uart_rx (rx),
          .uart_tx (tx),
          .uart_cts (0),
          .uart_rts (),
          .error ());

      localparam N = 3;

   dii_flit [N-1:0] dii_out; logic [N-1:0] dii_out_ready;
   dii_flit [N-1:0] dii_in; logic [N-1:0] dii_in_ready;   
   
   glip_channel #(.WIDTH(16)) fifo_in (.*); 
   glip_channel #(.WIDTH(16)) fifo_out (.*); 
   
   assign fifo_in.data = fifo_in_data;
   assign fifo_in.valid = fifo_in_valid;
   assign fifo_in_ready = fifo_in.ready;
   assign fifo_out_data = fifo_out.data;
   assign fifo_out_valid = fifo_out.valid;
   assign fifo_out.ready = fifo_out_ready;
   
   osd_him
     u_him(.*,
           .glip_in  (fifo_in),
           .glip_out (fifo_out),
           .dii_out        ( dii_out[0]        ),
           .dii_out_ready  ( dii_out_ready[0]  ),
           .dii_in         ( dii_in[0]         ),
           .dii_in_ready   ( dii_in_ready[0]   )
           );
   
   osd_scm
     #(.SYSTEMID(16'hdead), .NUM_MOD(N-1))
   u_scm(.*,
         .id (10'd1),
         .debug_in        ( dii_in[1]        ),
         .debug_in_ready  ( dii_in_ready[1]  ),
         .debug_out       ( dii_out[1]       ),
         .debug_out_ready ( dii_out_ready[1] )
         );

   assign uart_r_data[31:8] = 0;
   
   osd_dem_uart_nasti
     u_uart (.*,
             .id (10'd2),

             .ar_addr (uart_ar_addr[4:2]),
             .ar_valid (uart_ar_valid),
             .ar_ready (uart_ar_ready),
             .r_data (uart_r_data[7:0]),
             .r_valid (uart_r_valid),
             .r_ready (uart_r_ready),
             .r_resp (uart_r_resp),
             .aw_addr (uart_aw_addr[4:2]),
             .aw_valid (uart_aw_valid),
             .aw_ready (uart_aw_ready),
             .w_data (uart_w_data),
             .w_valid (uart_w_valid),
             .w_ready (uart_w_ready),
             .b_valid (uart_b_valid),
             .b_ready (uart_b_ready),
             .b_resp (uart_b_resp),
             
             .debug_in        ( dii_in[2]        ),
             .debug_in_ready  ( dii_in_ready[2]  ),
             .debug_out       ( dii_out[2]       ),
             .debug_out_ready ( dii_out_ready[2] )
             );
   
   debug_ring
     #(.PORTS(N))
             u_ring(.*,
                    .dii_in        ( dii_out       ),
                    .dii_in_ready  ( dii_out_ready ),
                    .dii_out       ( dii_in        ),
                    .dii_out_ready ( dii_in_ready  )
                    );
endmodule // debug_system
