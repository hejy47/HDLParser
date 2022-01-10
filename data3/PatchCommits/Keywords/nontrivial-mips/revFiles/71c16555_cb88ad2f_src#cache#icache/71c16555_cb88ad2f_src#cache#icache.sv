`include "common_defs.svh"

module icache #(
	parameter BUS_WIDTH = 4,
	parameter DATA_WIDTH = 64, 
	parameter LINE_WIDTH = 256, 
	parameter SET_ASSOC  = 4,
	parameter CACHE_SIZE = 16 * 1024 * 8
) (
	// external logics
	input  logic        clk,
	input  logic        rst,
	// invalidation requests
	input  logic        invalidate_icache,
	input  logic [31:0] invalidate_addr,
	// CPU signals
	cpu_ibus_if.slave   ibus,
	// AXI request
    output axi_req_t                axi_req,
    output logic [BUS_WIDTH - 1 :0] axi_req_arid,
    output logic [BUS_WIDTH - 1 :0] axi_req_awid,
    output logic [BUS_WIDTH - 1 :0] axi_req_wid,
	// AXI response
    input  axi_resp_t               axi_resp,
    input  logic [BUS_WIDTH - 1 :0] axi_resp_rid,
    input  logic [BUS_WIDTH - 1 :0] axi_resp_bid
);

localparam int LINE_NUM    = CACHE_SIZE / LINE_WIDTH;
localparam int GROUP_NUM   = LINE_NUM / SET_ASSOC;
localparam int DATA_PER_LINE = LINE_WIDTH / DATA_WIDTH;

localparam int DATA_BYTE_OFFSET = $clog2(DATA_WIDTH / 8);
localparam int LINE_BYTE_OFFSET = $clog2(LINE_WIDTH / 8);
localparam int INDEX_WIDTH = $clog2(GROUP_NUM);
localparam int TAG_WIDTH   = 32 - INDEX_WIDTH - LINE_BYTE_OFFSET;

typedef enum logic [2:0] {
	IDLE,
	WAIT_AXI_READY,
	RECEIVING,
	REFILL,
	FINISH,
	FLUSH_WAIT_AXI_READY,
	FLUSH_RECEIVING,
	INVALIDATING
} state_t;

typedef struct packed {
	logic valid;
	logic [TAG_WIDTH-1:0] tag;
} tag_t;

typedef logic [DATA_PER_LINE-1:0][DATA_WIDTH-1:0] line_t;
typedef logic [INDEX_WIDTH-1:0] index_t;
typedef logic [LINE_BYTE_OFFSET-DATA_BYTE_OFFSET-1:0] offset_t;

function index_t get_index( input logic [31:0] addr );
	return addr[LINE_BYTE_OFFSET + INDEX_WIDTH - 1 : LINE_BYTE_OFFSET];
endfunction

function logic [TAG_WIDTH-1:0] get_tag( input logic [31:0] addr );
	return addr[31 : LINE_BYTE_OFFSET + INDEX_WIDTH];
endfunction

function offset_t get_offset( input logic [31:0] addr );
	return addr[LINE_BYTE_OFFSET - 1 : DATA_BYTE_OFFSET];
endfunction

// index invalidation signals
logic pipe_inv;
index_t pipe_inv_index;

// RAM requests of tag
tag_t [SET_ASSOC-1:0] tag_rdata;
tag_t tag_wdata;
logic [SET_ASSOC-1:0] tag_we;

// RAM requests of line data
line_t [SET_ASSOC-1:0] data_rdata;
line_t data_wdata;
logic [SET_ASSOC-1:0] data_we;
index_t ram_raddr, ram_waddr;

// random number
logic lfsr_update;
logic [7:0] lfsr_val;

// stage 2 status
logic pipe_read, pipe_flush;
logic [31:0] pipe_addr, axi_raddr;
logic cache_miss;
logic [SET_ASSOC-1:0] hit;
logic [LINE_WIDTH/32-1:0][31:0] line_recv;
state_t state_d, state;
logic [LINE_BYTE_OFFSET-1:0] burst_cnt, burst_cnt_d;
logic [$clog2(SET_ASSOC)-1:0] assoc_waddr;

// setup write request
assign assoc_waddr     = lfsr_val[$clog2(SET_ASSOC)-1:0];
assign tag_wdata.valid = state != INVALIDATING && ~pipe_inv;
assign tag_wdata.tag   = get_tag(pipe_addr);
always_comb begin
	data_wdata = line_recv;
	data_wdata[DATA_PER_LINE - 1][DATA_WIDTH - 1 -: 32] = axi_resp.rdata;
end

// cache miss? 
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_hit
	assign hit[i] = tag_rdata[i].valid & (get_tag(pipe_addr) == tag_rdata[i].tag);
end
assign cache_miss = ~(|hit) & pipe_read;

// invalidate counter
index_t invalite_cnt, invalite_cnt_d;

// stall signals
assign ibus.stall = (state_d != IDLE) && ~pipe_flush && pipe_read || state == INVALIDATING;
assign ibus.ready = state != INVALIDATING;

// send rddata next cycle
logic [SET_ASSOC-1:0] pipe_hit;
logic [SET_ASSOC-1:0][DATA_WIDTH-1:0] pipe_rdata, pipe_rdata_extra;
logic pipe_rddata_valid, pipe_rddata_extra_valid;
always_comb begin
	ibus.valid        = pipe_rddata_valid;
	ibus.extra_valid  = pipe_rddata_extra_valid;
	ibus.rddata       = '0;
	ibus.rddata_extra = '0;
	for(int i = 0; i < SET_ASSOC; ++i) begin
		ibus.rddata |= {DATA_WIDTH{pipe_hit[i]}} & pipe_rdata[i];
		ibus.rddata_extra |= {DATA_WIDTH{pipe_hit[i]}} & pipe_rdata_extra[i];
	end
end

offset_t next_offset;
assign next_offset = get_offset(pipe_addr) + 1;
always_ff @(posedge clk) begin
	if(rst) begin
		pipe_hit <= '0;
		pipe_rdata <= '0;
		pipe_rdata_extra <= '0;
		pipe_rddata_valid <= 1'b0;
		pipe_rddata_extra_valid <= 1'b0;
	end else begin
		pipe_hit <= hit;
		pipe_rddata_valid <= pipe_read & ~ibus.stall & ~ibus.flush_2;
		pipe_rddata_extra_valid <= ~&get_offset(pipe_addr);
		for(int i = 0; i < SET_ASSOC; ++i) begin
			pipe_rdata[i]       <= data_rdata[i][get_offset(pipe_addr)];
			pipe_rdata_extra[i] <= data_rdata[i][next_offset];
		end
	end
end

// AXI Plumbing
assign axi_req_arid = '0;
assign axi_req_awid = '0;
assign axi_req_wid = '0;

always_comb begin
	// RAM requests
	tag_we      = '0;
	data_we     = '0;
	ram_waddr   = get_index(pipe_addr);
	if(state_d == FINISH && ~pipe_flush && pipe_read) begin
		ram_raddr    = get_index(pipe_addr);
	end else begin
		ram_raddr    = get_index(ibus.address);
	end

	lfsr_update = 1'b0;
	burst_cnt_d = burst_cnt;
	invalite_cnt_d = '0;

	// AXI defaults
	axi_req = '0;
	axi_req.arlen   = LINE_WIDTH / 32 - 1;
	axi_req.arsize  = 3'b010; // 4 bytes
	axi_req.arburst = 2'b01;  // INCR
	axi_raddr  = { pipe_addr[31 : LINE_BYTE_OFFSET], {LINE_BYTE_OFFSET{1'b0}} };

	case(state)
		WAIT_AXI_READY, FLUSH_WAIT_AXI_READY: begin
			burst_cnt_d     = '0;
			axi_req.arvalid = 1'b1;
			axi_req.araddr  = axi_raddr;
		end
		RECEIVING: begin
			if(axi_resp.rvalid & ~pipe_inv) begin
				axi_req.rready = 1'b1;
				burst_cnt_d    = burst_cnt + 1;
			end

			if(axi_resp.rvalid & axi_resp.rlast) begin
				tag_we[assoc_waddr]  = 1'b1; // ~ibus.flush_2;
				data_we[assoc_waddr] = 1'b1; // ~ibus.flush_2;
				lfsr_update = 1'b1;
			end
		end
		FLUSH_RECEIVING: begin
			axi_req.rready = 1'b1;
		end
		INVALIDATING: begin
			invalite_cnt_d = invalite_cnt + 1;
			tag_we    = '1;
			ram_waddr = invalite_cnt;
		end
	endcase

	if(pipe_inv) begin
		tag_we    = '1;
		ram_waddr = pipe_inv_index;
	end
end

// update state
always_comb begin
	state_d = state;
	unique case(state)
		IDLE, FINISH:
			if(cache_miss & ~pipe_flush)
				state_d = WAIT_AXI_READY;
			else state_d = IDLE;
		WAIT_AXI_READY:
			if(axi_resp.arready) 
				state_d = pipe_flush ? FLUSH_RECEIVING : RECEIVING;
			else if(pipe_flush)
				state_d = FLUSH_WAIT_AXI_READY;
		FLUSH_WAIT_AXI_READY:
			if(axi_resp.arready) 
				state_d = FLUSH_RECEIVING;
		RECEIVING, FLUSH_RECEIVING:
			if(axi_resp.rvalid & axi_resp.rlast & ~pipe_inv) begin
				state_d = REFILL;
			end else if(pipe_flush) begin
				state_d = FLUSH_RECEIVING;
			end
		REFILL: state_d = FINISH;
		INVALIDATING:
			if(&invalite_cnt) state_d = IDLE;
	endcase
end

logic icache_miss;
assign icache_miss = cache_miss & ~ibus.flush_2 && (state == IDLE || state == FINISH);

always_ff @(posedge clk) begin
	if(rst) begin
		line_recv <= '0;
	end else if(state == RECEIVING && axi_resp.rvalid) begin
		line_recv[burst_cnt] <= axi_resp.rdata;
	end

	if(rst) begin
		state        <= INVALIDATING;
		burst_cnt    <= '0;
		invalite_cnt <= '0;
	end else begin
		state        <= state_d;
		burst_cnt    <= burst_cnt_d;
		invalite_cnt <= invalite_cnt_d;
	end
end

always_ff @(posedge clk) begin
	if(rst) begin
		pipe_addr <= '0;
		pipe_read <= 1'b0;
	end else if(~ibus.stall || pipe_flush) begin
		pipe_read <= ibus.read & ~ibus.flush_1;
		pipe_addr <= ibus.address;
	end

	if(rst) begin
		pipe_flush <= 1'b0;
		pipe_inv   <= 1'b0;
		pipe_inv_index <= '0;
	end else begin
		pipe_flush <= ibus.flush_2;
		pipe_inv   <= invalidate_icache;
		pipe_inv_index <= get_index(invalidate_addr);
	end
end

// generate block RAMs
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_mem
	dual_port_lutram #(
		.SIZE  ( GROUP_NUM ),
		.dtype ( tag_t     )
	) mem_tag (
		.clk,
		.rst,

		.ena   ( 1'b1         ),
		.wea   ( tag_we[i]    ),
		.addra ( ram_waddr    ),
		.dina  ( tag_wdata    ),
		.douta (              ),

		.enb   ( 1'b1         ),
		.addrb ( ram_raddr    ),
		.doutb ( tag_rdata[i] )
	);

	dual_port_ram #(
		.SIZE  ( GROUP_NUM ),
		.dtype ( line_t    )
	) mem_data (
		.clk,
		.rst,

		.ena   ( 1'b1          ),
		.wea   ( data_we[i]    ),
		.addra ( ram_waddr     ),
		.dina  ( data_wdata    ),
		.douta (               ),

		.enb   ( 1'b1          ),
		.web   ( 1'b0          ),
		.addrb ( ram_raddr     ),
		.dinb  (               ),
		.doutb ( data_rdata[i] )
	);
end

// generate random number
lfsr_8bits lfsr_inst(
	.clk,
	.rst,
	.update ( lfsr_update ),
	.val    ( lfsr_val    )
);

endmodule
