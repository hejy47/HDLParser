-- #################################################################################################
-- # << NEORV32 - CPU Control >>                                                                   #
-- # ********************************************************************************************* #
-- # CPU operation is split into a fetch engine (responsible for fetching an decompressing instr-  #
-- # uctions), an execute engine (responsible for actually executing the instructions), an inter-  #
-- # rupt and exception handling controller and the RISC-V status and control registers (CSRs).    #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2020, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 Processor - https://github.com/stnolting/neorv32              (c) Stephan Nolting #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cpu_control is
  generic (
    -- General --
    CLOCK_FREQUENCY              : natural := 0; -- clock frequency of clk_i in Hz
    HART_ID                      : std_ulogic_vector(31 downto 0) := x"00000000"; -- custom hardware thread ID
    BOOTLOADER_USE               : boolean := true;   -- implement processor-internal bootloader?
    CSR_COUNTERS_USE             : boolean := true;   -- implement RISC-V perf. counters ([m]instret[h], [m]cycle[h], time[h])?
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C        : boolean := false;  -- implement compressed extension?
    CPU_EXTENSION_RISCV_E        : boolean := false;  -- implement embedded RF extension?
    CPU_EXTENSION_RISCV_M        : boolean := false;  -- implement muld/div extension?
    CPU_EXTENSION_RISCV_Zicsr    : boolean := true;   -- implement CSR system?
    CPU_EXTENSION_RISCV_Zifencei : boolean := true;   -- implement instruction stream sync.?
    -- Memory configuration: Instruction memory --
    MEM_ISPACE_BASE              : std_ulogic_vector(31 downto 0) := x"00000000"; -- base address of instruction memory space
    MEM_ISPACE_SIZE              : natural := 8*1024; -- total size of instruction memory space in byte
    MEM_INT_IMEM_USE             : boolean := true;   -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            : natural := 8*1024; -- size of processor-internal instruction memory in bytes
    MEM_INT_IMEM_ROM             : boolean := false;  -- implement processor-internal instruction memory as ROM
    -- Memory configuration: Data memory --
    MEM_DSPACE_BASE              : std_ulogic_vector(31 downto 0) := x"80000000"; -- base address of data memory space
    MEM_DSPACE_SIZE              : natural := 4*1024; -- total size of data memory space in byte
    MEM_INT_DMEM_USE             : boolean := true;   -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            : natural := 4*1024; -- size of processor-internal data memory in bytes
    -- Memory configuration: External memory interface --
    MEM_EXT_USE                  : boolean := false;  -- implement external memory bus interface?
    -- Processor peripherals --
    IO_GPIO_USE                  : boolean := true;   -- implement general purpose input/output port unit (GPIO)?
    IO_MTIME_USE                 : boolean := true;   -- implement machine system timer (MTIME)?
    IO_UART_USE                  : boolean := true;   -- implement universal asynchronous receiver/transmitter (UART)?
    IO_SPI_USE                   : boolean := true;   -- implement serial peripheral interface (SPI)?
    IO_TWI_USE                   : boolean := true;   -- implement two-wire interface (TWI)?
    IO_PWM_USE                   : boolean := true;   -- implement pulse-width modulation unit (PWM)?
    IO_WDT_USE                   : boolean := true;   -- implement watch dog timer (WDT)?
    IO_CLIC_USE                  : boolean := true;   -- implement core local interrupt controller (CLIC)?
    IO_TRNG_USE                  : boolean := true;   -- implement true random number generator (TRNG)?
    IO_DEVNULL_USE               : boolean := true    -- implement dummy device (DEVNULL)?
  );
  port (
    -- global control --
    clk_i         : in  std_ulogic; -- global clock, rising edge
    rstn_i        : in  std_ulogic; -- global reset, low-active, async
    ctrl_o        : out std_ulogic_vector(ctrl_width_c-1 downto 0); -- main control bus
    -- status input --
    alu_wait_i    : in  std_ulogic; -- wait for ALU
    bus_wait_i    : in  std_ulogic; -- wait for bus
    -- data input --
    instr_i       : in  std_ulogic_vector(data_width_c-1 downto 0); -- instruction
    cmp_i         : in  std_ulogic_vector(1 downto 0); -- comparator status
    alu_add_i     : in  std_ulogic_vector(data_width_c-1 downto 0); -- ALU.add result
    -- data output --
    imm_o         : out std_ulogic_vector(data_width_c-1 downto 0); -- immediate
    fetch_pc_o    : out std_ulogic_vector(data_width_c-1 downto 0); -- PC for instruction fetch
    curr_pc_o     : out std_ulogic_vector(data_width_c-1 downto 0); -- current PC (corresponding to current instruction)
    next_pc_o     : out std_ulogic_vector(data_width_c-1 downto 0); -- next PC (corresponding to current instruction)
    -- csr data interface --
    csr_wdata_i   : in  std_ulogic_vector(data_width_c-1 downto 0); -- CSR write data
    csr_rdata_o   : out std_ulogic_vector(data_width_c-1 downto 0); -- CSR read data
    -- external interrupt --
    clic_irq_i    : in  std_ulogic; -- CLIC interrupt request
    mtime_irq_i   : in  std_ulogic; -- machine timer interrupt
    -- bus access exceptions --
    mar_i         : in  std_ulogic_vector(data_width_c-1 downto 0);  -- memory address register
    ma_instr_i    : in  std_ulogic; -- misaligned instruction address
    ma_load_i     : in  std_ulogic; -- misaligned load data address
    ma_store_i    : in  std_ulogic; -- misaligned store data address
    be_instr_i    : in  std_ulogic; -- bus error on instruction access
    be_load_i     : in  std_ulogic; -- bus error on load data access
    be_store_i    : in  std_ulogic; -- bus error on store data access
    bus_busy_i    : in  std_ulogic  -- bus unit is busy
  );
end neorv32_cpu_control;

architecture neorv32_cpu_control_rtl of neorv32_cpu_control is

  -- instruction fetch enginge --
  type fetch_engine_state_t is (IFETCH_RESET, IFETCH_0, IFETCH_1, IFETCH_2, IFETCH_3);
  type fetch_engine_t is record
    state           : fetch_engine_state_t;
    state_nxt       : fetch_engine_state_t;
    i_buf           : std_ulogic_vector(33 downto 0);
    i_buf_nxt       : std_ulogic_vector(33 downto 0);
    i_buf2          : std_ulogic_vector(33 downto 0);
    i_buf2_nxt      : std_ulogic_vector(33 downto 0);
    ci_reg          : std_ulogic_vector(17 downto 0);
    ci_reg_nxt      : std_ulogic_vector(17 downto 0);
    i_buf_state     : std_ulogic_vector(01 downto 0);
    i_buf_state_nxt : std_ulogic_vector(01 downto 0);
    pc_real         : std_ulogic_vector(data_width_c-1 downto 0);
    pc_real_add     : std_ulogic_vector(data_width_c-1 downto 0);
    pc_fetch        : std_ulogic_vector(data_width_c-1 downto 0);
    pc_fetch_add    : std_ulogic_vector(data_width_c-1 downto 0);
    ci_return       : std_ulogic;
    ci_return_nxt   : std_ulogic;
    reset           : std_ulogic;
    bus_err_ack     : std_ulogic;
    bus_reset       : std_ulogic;
  end record;
  signal fetch_engine : fetch_engine_t;

  -- pre-decoder --
  signal ci_instr32 : std_ulogic_vector(31 downto 0);
  signal ci_illegal : std_ulogic;

  -- instrucion prefetch buffer (IPB) --
  type ipb_t is record
    wdata  : std_ulogic_vector(34 downto 0);
    rdata  : std_ulogic_vector(34 downto 0);
    waddr  : std_ulogic_vector(31 downto 0);
    raddr  : std_ulogic_vector(31 downto 0);
    status : std_ulogic;
    free   : std_ulogic;
    avail  : std_ulogic;
    we     : std_ulogic;
    re     : std_ulogic;
    clear  : std_ulogic;
  end record;
  signal ipb : ipb_t;

  -- instruction execution engine --
  type execute_engine_state_t is (SYS_WAIT, DISPATCH, TRAP, EXECUTE, ALU_WAIT, BRANCH, STORE, LOAD, LOADSTORE_0, LOADSTORE_1, CSR_ACCESS);
  type execute_engine_t is record
    state        : execute_engine_state_t;
    state_nxt    : execute_engine_state_t;
    state_prev   : execute_engine_state_t;
    i_reg        : std_ulogic_vector(31 downto 0);
    i_reg_nxt    : std_ulogic_vector(31 downto 0);
    is_ci        : std_ulogic; -- current instruction is de-compressed instruction
    is_ci_nxt    : std_ulogic;
    is_jump      : std_ulogic; -- current instruction is jump instruction
    is_jump_nxt  : std_ulogic;
    branch_taken : std_ulogic; -- branch condition fullfilled
    pc           : std_ulogic_vector(data_width_c-1 downto 0); -- actual PC, corresponding to current executed instruction
    pc_nxt       : std_ulogic_vector(data_width_c-1 downto 0);
    next_pc      : std_ulogic_vector(data_width_c-1 downto 0); -- next PC, corresponding to next instruction to be executed
    last_pc      : std_ulogic_vector(data_width_c-1 downto 0); -- PC of last executed instruction
  end record;
  signal execute_engine : execute_engine_t;

  -- trap controller --
  type trap_ctrl_t is record
    exc_buf       : std_ulogic_vector(exception_width_c-1 downto 0);
    exc_fire      : std_ulogic; -- set if there is a valid source in the exception buffer
    irq_buf       : std_ulogic_vector(interrupt_width_c-1 downto 0);
    irq_fire      : std_ulogic; -- set if there is a valid source in the interrupt buffer
    exc_ack       : std_ulogic; -- acknowledge all exceptions
    irq_ack       : std_ulogic_vector(interrupt_width_c-1 downto 0); -- acknowledge specific interrupt
    irq_ack_nxt   : std_ulogic_vector(interrupt_width_c-1 downto 0);
    cause         : std_ulogic_vector(data_width_c-1 downto 0); -- trap ID (for "mcause")
    cause_nxt     : std_ulogic_vector(data_width_c-1 downto 0);
    exc_src       : std_ulogic_vector(exception_width_c-1 downto 0);
    --
    env_start     : std_ulogic; -- start trap handler env
    env_start_ack : std_ulogic; -- start of trap handler acknowledged
    env_end       : std_ulogic; -- end trap handler env
    --
    instr_be      : std_ulogic; -- instruction fetch bus error
    instr_ma      : std_ulogic; -- instruction fetch misaligned address
    instr_il      : std_ulogic; -- illegal instruction
    env_call      : std_ulogic;
    break_point   : std_ulogic;
  end record;
  signal trap_ctrl : trap_ctrl_t;
  
  -- CPU control signals --
  signal ctrl_nxt, ctrl : std_ulogic_vector(ctrl_width_c-1 downto 0);

  -- fast bus access --
  signal bus_fast_ir : std_ulogic;

  -- RISC-V control and status registers (CSRs) --
  type csr_t is record
    we           : std_ulogic; -- write enable
    we_nxt       : std_ulogic;
    re           : std_ulogic; -- read enable
    re_nxt       : std_ulogic;
    mstatus_mie  : std_ulogic; -- mstatus.MIE: global IRQ enable (R/W)
    mstatus_mpie : std_ulogic; -- mstatus.MPIE: previous global IRQ enable (R/-)
    mip_msip     : std_ulogic; -- mip.MSIP: machine software interrupt pending (R/W)
    mie_msie     : std_ulogic; -- mie.MSIE: machine software interrupt enable (R/W)
    mie_meie     : std_ulogic; -- mie.MEIE: machine external interrupt enable (R/W)
    mie_mtie     : std_ulogic; -- mie.MEIE: machine timer interrupt enable (R/W)
    mepc         : std_ulogic_vector(data_width_c-1 downto 0); -- mepc: machine exception pc (R/W)
    mcause       : std_ulogic_vector(data_width_c-1 downto 0); -- mcause: machine trap cause (R/W)
    mtvec        : std_ulogic_vector(data_width_c-1 downto 0); -- mtvec: machine trap-handler base address (R/W)
    mtval        : std_ulogic_vector(data_width_c-1 downto 0); -- mtval: machine bad address or isntruction (R/W)
    mscratch     : std_ulogic_vector(data_width_c-1 downto 0); -- mscratch: scratch register (R/W)
    cycle        : std_ulogic_vector(32 downto 0); -- cycle, mtime (R/-), plus carry bit
    instret      : std_ulogic_vector(32 downto 0); -- instret (R/-), plus carry bit
    cycleh       : std_ulogic_vector(31 downto 0); -- cycleh, mtimeh (R/-)
    instreth     : std_ulogic_vector(31 downto 0); -- instreth (R/-)
  end record;
  signal csr : csr_t;

  signal cycle_msb   : std_ulogic;
  signal instret_msb : std_ulogic;

  -- illegal instruction check --
  signal illegal_instruction : std_ulogic;
  signal illegal_register    : std_ulogic; -- only for E-extension
  signal illegal_compressed  : std_ulogic; -- only fir C-extension

begin

-- ****************************************************************************************************************************
-- Instruction Fetch
-- ****************************************************************************************************************************

  -- Compressed Instructions Recoding -------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_cpu_decompressor_inst_true:
  if (CPU_EXTENSION_RISCV_C = true) generate
    neorv32_cpu_decompressor_inst: neorv32_cpu_decompressor
    port map (
      -- instruction input --
      ci_instr16_i => fetch_engine.ci_reg(15 downto 0), -- compressed instruction input
      -- instruction output --
      ci_illegal_o => ci_illegal, -- is an illegal compressed instruction
      ci_instr32_o => ci_instr32  -- 32-bit decompressed instruction
    );
  end generate;

  neorv32_cpu_decompressor_inst_false:
  if (CPU_EXTENSION_RISCV_C = false) generate
    ci_instr32 <= (others => '0');
    ci_illegal <= '0';
  end generate;


  -- Fetch Engine FSM Sync ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- for registers that require a specific reset state --
  fetch_engine_fsm_sync_rst: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      fetch_engine.state <= IFETCH_RESET;
    elsif rising_edge(clk_i) then
      if (fetch_engine.reset = '1') then
        fetch_engine.state <= IFETCH_RESET;
      else
        fetch_engine.state <= fetch_engine.state_nxt;
      end if;
    end if;
  end process fetch_engine_fsm_sync_rst;


  -- for registers that DO NOT require a specific reset state --
  fetch_engine_fsm_sync: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (fetch_engine.state = IFETCH_RESET) then
        fetch_engine.pc_fetch  <= execute_engine.pc(data_width_c-1 downto 1) & '0'; -- initialize with "real" application PC
        fetch_engine.pc_real   <= execute_engine.pc(data_width_c-1 downto 1) & '0'; -- initialize with "real" application PC
      else
        fetch_engine.pc_real   <= std_ulogic_vector(unsigned(fetch_engine.pc_real(data_width_c-1 downto 1) & '0')  + unsigned(fetch_engine.pc_real_add(data_width_c-1 downto 1) & '0'));
        fetch_engine.pc_fetch  <= std_ulogic_vector(unsigned(fetch_engine.pc_fetch(data_width_c-1 downto 1) & '0') + unsigned(fetch_engine.pc_fetch_add(data_width_c-1 downto 1) & '0'));
      end if;
      --
      fetch_engine.i_buf       <= fetch_engine.i_buf_nxt;
      fetch_engine.i_buf2      <= fetch_engine.i_buf2_nxt;
      fetch_engine.i_buf_state <= fetch_engine.i_buf_state_nxt;
      --
      fetch_engine.ci_reg      <= fetch_engine.ci_reg_nxt;
      fetch_engine.ci_return   <= fetch_engine.ci_return_nxt;
    end if;
  end process fetch_engine_fsm_sync;


  -- Fetch Engine FSM Comb ------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  fetch_engine_fsm_comb: process(fetch_engine, execute_engine, csr, ipb, instr_i, bus_wait_i, bus_busy_i, ci_instr32, be_instr_i, ma_instr_i)
  begin
    -- arbiter defaults --
    fetch_engine.state_nxt       <= fetch_engine.state;
    fetch_engine.pc_fetch_add    <= (others => '0');
    fetch_engine.pc_real_add     <= (others => '0');
    bus_fast_ir                  <= '0';
    fetch_engine.i_buf_nxt       <= fetch_engine.i_buf;
    fetch_engine.i_buf2_nxt      <= fetch_engine.i_buf2;
    fetch_engine.i_buf_state_nxt <= fetch_engine.i_buf_state;
    fetch_engine.ci_reg_nxt      <= fetch_engine.ci_reg;
    fetch_engine.ci_return_nxt   <= fetch_engine.ci_return;
    fetch_engine.bus_err_ack     <= '0';
    fetch_engine.bus_reset       <= '0';

    -- instruction prefetch buffer interface --
    ipb.we    <= '0';
    ipb.clear <= '0';
    ipb.wdata <= fetch_engine.i_buf2(33 downto 32) & '0' & fetch_engine.i_buf2(31 downto 0);
    ipb.waddr <= fetch_engine.pc_real(data_width_c-1 downto 1) & '0';

    -- state machine --
    case fetch_engine.state is

      when IFETCH_RESET => -- reset engine, prefetch buffer, get PC
      -- ------------------------------------------------------------
        fetch_engine.i_buf_state_nxt <= (others => '0');
        fetch_engine.ci_return_nxt   <= '0';
        fetch_engine.bus_reset       <= '1'; -- reset bus unit
        ipb.clear                    <= '1'; -- clear instruction prefetch buffer
        fetch_engine.state_nxt       <= IFETCH_0;

      when IFETCH_0 => -- output current PC to bus system, request 32-bit word
      -- ------------------------------------------------------------
        if (bus_busy_i = '0') and (execute_engine.state /= LOAD) and (execute_engine.state /= STORE) and
                                  (execute_engine.state /= LOADSTORE_0) and (execute_engine.state /= LOADSTORE_1) then -- wait if execute engine is using bus unit
          bus_fast_ir            <= '1'; -- fast instruction fetch request (output PC to bus.address)
          fetch_engine.state_nxt <= IFETCH_1;
        end if;

      when IFETCH_1 => -- store data from memory to buffer(s)
      -- ------------------------------------------------------------
        fetch_engine.i_buf_nxt  <= be_instr_i & ma_instr_i & instr_i(31 downto 0); -- store data word and exception info
        if (bus_wait_i = '0') then -- wait for bus response
          fetch_engine.i_buf2_nxt <= fetch_engine.i_buf;
          fetch_engine.i_buf_state_nxt(1) <= fetch_engine.i_buf_state(0);
          fetch_engine.state_nxt          <= IFETCH_2;
        end if;

        fetch_engine.i_buf_state_nxt(0) <= '1';
        if (be_instr_i = '1') or (ma_instr_i = '1') then -- any fetch exception?
          fetch_engine.bus_err_ack <= '1'; -- ack bus errors, the execute engine has to take care of them
        end if;

      when IFETCH_2 => -- construct instruction and issue
      -- ------------------------------------------------------------
        if (fetch_engine.i_buf_state(1) = '1') then
          if (fetch_engine.pc_fetch(1) = '0') or (CPU_EXTENSION_RISCV_C = false) then -- 32-bit aligned
            fetch_engine.ci_reg_nxt <= fetch_engine.i_buf2(33 downto 32) & fetch_engine.i_buf2(15 downto 00);
            ipb.wdata <= fetch_engine.i_buf2(33 downto 32) & '0' & fetch_engine.i_buf2(31 downto 0);
            
            if (fetch_engine.i_buf2(01 downto 00) = "11") or (CPU_EXTENSION_RISCV_C = false) then -- uncompressed
              if (ipb.free = '1') then -- free entry in buffer?
                ipb.we                    <= '1';
                fetch_engine.pc_real_add  <= std_ulogic_vector(to_unsigned(4, data_width_c));
                fetch_engine.pc_fetch_add <= std_ulogic_vector(to_unsigned(4, data_width_c));
                fetch_engine.state_nxt    <= IFETCH_0;
              end if;
              
            else -- compressed
              fetch_engine.pc_fetch_add  <= std_ulogic_vector(to_unsigned(2, data_width_c));
              fetch_engine.ci_return_nxt <= '1'; -- come back here after issueing
              fetch_engine.state_nxt     <= IFETCH_3;
            end if;
            
          else -- 16-bit aligned
            fetch_engine.ci_reg_nxt <= fetch_engine.i_buf2(33 downto 32) & fetch_engine.i_buf2(31 downto 16);
            ipb.wdata <= fetch_engine.i_buf(33 downto 32) & '0' & fetch_engine.i_buf(15 downto 00) & fetch_engine.i_buf2(31 downto 16);
            
            if (fetch_engine.i_buf2(17 downto 16) = "11") then -- uncompressed
              if (ipb.free = '1') then -- free entry in buffer?
                ipb.we                    <= '1';
                fetch_engine.pc_real_add  <= std_ulogic_vector(to_unsigned(4, data_width_c));
                fetch_engine.pc_fetch_add <= std_ulogic_vector(to_unsigned(4, data_width_c));
                fetch_engine.state_nxt    <= IFETCH_0;
              end if;
              
            else -- compressed
              fetch_engine.pc_fetch_add  <= std_ulogic_vector(to_unsigned(2, data_width_c));
              fetch_engine.ci_return_nxt <= '0'; -- start next fetch after issueing
              fetch_engine.state_nxt     <= IFETCH_3;
            end if;
          end if;
        else
         fetch_engine.pc_fetch_add <= std_ulogic_vector(to_unsigned(4, data_width_c));
         fetch_engine.state_nxt    <= IFETCH_0;
        end if;

      when IFETCH_3 => -- additional cycle for issueing decompressed instructions
      -- ------------------------------------------------------------
        if (ipb.free = '1') then -- free entry in buffer?
          ipb.we    <= '1';
          ipb.wdata <= fetch_engine.ci_reg(17 downto 16) & '1' & ci_instr32;
          fetch_engine.pc_real_add <= std_ulogic_vector(to_unsigned(2, data_width_c));
          if (fetch_engine.ci_return = '0') then
            fetch_engine.state_nxt <= IFETCH_0;
          else
            fetch_engine.state_nxt <= IFETCH_2;
          end if;
        end if;

      when others => -- undefined
      -- ------------------------------------------------------------
        fetch_engine.state_nxt <= IFETCH_RESET;

    end case;
  end process fetch_engine_fsm_comb;


-- ****************************************************************************************************************************
-- Instruction Prefetch Buffer
-- ****************************************************************************************************************************


  -- Instruction Prefetch Buffer Stage ------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  instr_prefetch_buffer: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      ipb.status <= '0';
      ipb.rdata  <= (others => '0');
      ipb.raddr  <= (others => '0');
    elsif rising_edge(clk_i) then
      if (ipb.clear = '1') then
        ipb.status <= '0';
      elsif (ipb.we = '1') then
        ipb.status <= '1';
      elsif (ipb.re = '1') then
        ipb.status <= '0';
      end if;
      if (ipb.we = '1') then
        ipb.rdata <= ipb.wdata;
        ipb.raddr <= ipb.waddr;
      end if;
    end if;
  end process instr_prefetch_buffer;

  -- status --
  ipb.free  <= not ipb.status;
  ipb.avail <= ipb.status;


-- ****************************************************************************************************************************
-- Instruction Execution
-- ****************************************************************************************************************************


  -- Immediate Generator --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  imm_gen: process(clk_i)
  begin
    if rising_edge(clk_i) then
      case execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) is
        when opcode_store_c => -- S-immediate
          imm_o(31 downto 11) <= (others => execute_engine.i_reg(31)); -- sign extension
          imm_o(10 downto 05) <= execute_engine.i_reg(30 downto 25);
          imm_o(04 downto 01) <= execute_engine.i_reg(11 downto 08);
          imm_o(00)           <= execute_engine.i_reg(07);
        when opcode_branch_c => -- B-immediate
          imm_o(31 downto 12) <= (others => execute_engine.i_reg(31)); -- sign extension
          imm_o(11)           <= execute_engine.i_reg(07);
          imm_o(10 downto 05) <= execute_engine.i_reg(30 downto 25);
          imm_o(04 downto 01) <= execute_engine.i_reg(11 downto 08);
          imm_o(00)           <= '0';
        when opcode_lui_c | opcode_auipc_c => -- U-immediate
          imm_o(31 downto 20) <= execute_engine.i_reg(31 downto 20);
          imm_o(19 downto 12) <= execute_engine.i_reg(19 downto 12);
          imm_o(11 downto 00) <= (others => '0');
        when opcode_jal_c => -- J-immediate
          imm_o(31 downto 20) <= (others => execute_engine.i_reg(31)); -- sign extension
          imm_o(19 downto 12) <= execute_engine.i_reg(19 downto 12);
          imm_o(11)           <= execute_engine.i_reg(20);
          imm_o(10 downto 05) <= execute_engine.i_reg(30 downto 25);
          imm_o(04 downto 01) <= execute_engine.i_reg(24 downto 21);
          imm_o(00)           <= '0';
        when opcode_syscsr_c => -- CSR-immediate
          imm_o(31 downto 05) <= (others => '0');
          imm_o(04 downto 00) <= execute_engine.i_reg(19 downto 15);
        when others => -- I-immediate
          imm_o(31 downto 11) <= (others => execute_engine.i_reg(31)); -- sign extension
          imm_o(10 downto 05) <= execute_engine.i_reg(30 downto 25);
          imm_o(04 downto 01) <= execute_engine.i_reg(24 downto 21);
          imm_o(00)           <= execute_engine.i_reg(20);
      end case;
    end if;
  end process imm_gen;


  -- Branch Condition Check -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  branch_check: process(execute_engine.i_reg, cmp_i)
  begin
    case execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) is
      when funct3_beq_c => -- branch if equal
        execute_engine.branch_taken <= cmp_i(alu_cmp_equal_c);
      when funct3_bne_c => -- branch if not equal
        execute_engine.branch_taken <= not cmp_i(alu_cmp_equal_c);
      when funct3_blt_c | funct3_bltu_c => -- branch if less (signed/unsigned)
        execute_engine.branch_taken <= cmp_i(alu_cmp_less_c);
      when funct3_bge_c | funct3_bgeu_c => -- branch if greater or equal (signed/unsigned)
        execute_engine.branch_taken <= not cmp_i(alu_cmp_less_c);
      when others => -- undefined
        execute_engine.branch_taken <= '0';
    end case;
  end process branch_check;


  -- Execute Engine FSM Sync ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  -- for registers that require a specific reset state --
  execute_engine_fsm_sync_rst: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      if (BOOTLOADER_USE = true) then -- boot from bootloader ROM
        execute_engine.pc      <= boot_base_c(data_width_c-1 downto 1) & '0';
        execute_engine.last_pc <= boot_base_c(data_width_c-1 downto 1) & '0';
      else -- boot from IMEM
        execute_engine.pc      <= MEM_ISPACE_BASE(data_width_c-1 downto 1) & '0';
        execute_engine.last_pc <= MEM_ISPACE_BASE(data_width_c-1 downto 1) & '0';
      end if;
      execute_engine.state      <= SYS_WAIT;
      execute_engine.state_prev <= SYS_WAIT;
    elsif rising_edge(clk_i) then
      execute_engine.pc <= execute_engine.pc_nxt(data_width_c-1 downto 1) & '0';
      if (execute_engine.state = EXECUTE) then
        execute_engine.last_pc <= execute_engine.pc(data_width_c-1 downto 1) & '0';
      end if;
      execute_engine.state      <= execute_engine.state_nxt;
      execute_engine.state_prev <= execute_engine.state;
    end if;
  end process execute_engine_fsm_sync_rst;


  -- for registers that DO NOT require a specific reset state --
  execute_engine_fsm_sync: process(clk_i)
  begin
    if rising_edge(clk_i) then
      execute_engine.i_reg   <= execute_engine.i_reg_nxt;
      execute_engine.is_ci   <= execute_engine.is_ci_nxt;
      execute_engine.is_jump <= execute_engine.is_jump_nxt;
      -- control signals --
      ctrl <= ctrl_nxt;
    end if;
  end process execute_engine_fsm_sync;


  -- PC output --
  execute_engine.next_pc <= std_ulogic_vector(unsigned(execute_engine.pc(data_width_c-1 downto 1) & '0') + 2) when (execute_engine.is_ci = '1') else
                            std_ulogic_vector(unsigned(execute_engine.pc(data_width_c-1 downto 1) & '0') + 4);
  fetch_pc_o <= fetch_engine.pc_fetch(data_width_c-1 downto 1) & '0';
  curr_pc_o  <= execute_engine.pc(data_width_c-1 downto 1) & '0';
  next_pc_o  <= execute_engine.next_pc(data_width_c-1 downto 1) & '0';


  -- CPU Control Bus Output -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  ctrl_output: process(ctrl, execute_engine, fetch_engine, trap_ctrl, csr, bus_fast_ir)
  begin
    ctrl_o <= ctrl;
    -- direct output of register addresses --
    ctrl_o(ctrl_rf_rd_adr4_c  downto ctrl_rf_rd_adr0_c)  <= execute_engine.i_reg(instr_rd_msb_c  downto instr_rd_lsb_c);
    ctrl_o(ctrl_rf_rs1_adr4_c downto ctrl_rf_rs1_adr0_c) <= execute_engine.i_reg(instr_rs1_msb_c downto instr_rs1_lsb_c);
    ctrl_o(ctrl_rf_rs2_adr4_c downto ctrl_rf_rs2_adr0_c) <= execute_engine.i_reg(instr_rs2_msb_c downto instr_rs2_lsb_c);
    -- bus access requests --
    ctrl_o(ctrl_bus_if_c) <= ctrl(ctrl_bus_if_c) or bus_fast_ir;
    -- bus control --
    ctrl_o(ctrl_bus_exc_ack_c) <= trap_ctrl.env_start_ack or fetch_engine.bus_err_ack;
    ctrl_o(ctrl_bus_reset_c) <=fetch_engine.bus_reset;
  end process ctrl_output;


  -- Execute Engine FSM Comb ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  execute_engine_fsm_comb: process(execute_engine, fetch_engine, ipb, trap_ctrl, csr, ctrl, 
                                   alu_add_i, alu_wait_i, bus_wait_i, ma_load_i, be_load_i, ma_store_i, be_store_i)
    variable alu_immediate_v : std_ulogic;
    variable alu_operation_v : std_ulogic_vector(2 downto 0);
    variable rd_is_r0_v      : std_ulogic;
    variable rs1_is_r0_v     : std_ulogic;
  begin
    -- arbiter defaults --
    execute_engine.state_nxt   <= execute_engine.state;
    execute_engine.i_reg_nxt   <= execute_engine.i_reg;
    execute_engine.is_jump_nxt <= '0';
    execute_engine.is_ci_nxt   <= execute_engine.is_ci;
    execute_engine.pc_nxt      <= execute_engine.pc(data_width_c-1 downto 1) & '0';

    -- instruction dispatch --
    fetch_engine.reset         <= '0';
    ipb.re                     <= '0';

    -- trap environment control --
    trap_ctrl.env_start_ack    <= '0';
    trap_ctrl.env_end          <= '0';

    -- exception trigger --
    trap_ctrl.instr_be         <= '0';
    trap_ctrl.instr_ma         <= '0';
    trap_ctrl.env_call         <= '0';
    trap_ctrl.break_point      <= '0';

    -- CSR access --
    csr.we_nxt                 <= '0';
    csr.re_nxt                 <= '0';

    -- control defaults --
    ctrl_nxt <= (others => '0'); -- all off at first
    ctrl_nxt(ctrl_bus_unsigned_c) <= execute_engine.i_reg(instr_funct3_msb_c); -- unsigned LOAD (LBU, LHU)
    if (execute_engine.i_reg(instr_opcode_lsb_c+4) = '1') then -- ALU ops
      ctrl_nxt(ctrl_alu_unsigned_c) <= execute_engine.i_reg(instr_funct3_lsb_c+0); -- unsigned ALU operation (SLTIU, SLTU)
    else -- branches
      ctrl_nxt(ctrl_alu_unsigned_c) <= execute_engine.i_reg(instr_funct3_lsb_c+1); -- unsigned branches (BLTU, BGEU)
    end if;
    ctrl_nxt(ctrl_alu_shift_dir_c) <= execute_engine.i_reg(instr_funct3_msb_c); -- shift direction
    ctrl_nxt(ctrl_alu_shift_ar_c)  <= execute_engine.i_reg(30); -- arithmetic shift
    ctrl_nxt(ctrl_bus_size_lsb_c)  <= execute_engine.i_reg(instr_funct3_lsb_c+0); -- transfer size lsb (00=byte, 01=half-word)
    ctrl_nxt(ctrl_bus_size_msb_c)  <= execute_engine.i_reg(instr_funct3_lsb_c+1); -- transfer size msb (10=word, 11=?)
    ctrl_nxt(ctrl_alu_cmd2_c  downto ctrl_alu_cmd0_c)  <= alu_cmd_add_c; -- actual ALU operation = add
    ctrl_nxt(ctrl_cp_cmd2_c   downto ctrl_cp_cmd0_c)   <= execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c); -- CP operation
    ctrl_nxt(ctrl_cp_id_msb_c downto ctrl_cp_id_lsb_c) <= cp_sel_muldiv_c; -- only CP0 implemented yet

    -- is immediate operation? --
    alu_immediate_v := '0';
    if (execute_engine.i_reg(instr_opcode_msb_c-1) = '0') then
      alu_immediate_v := '1';
    end if;

    -- alu operation re-coding --
    case execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) is
      when funct3_subadd_c => -- SUB / ADD(I)
        if (alu_immediate_v = '0') and (execute_engine.i_reg(instr_funct7_msb_c-1) = '1') then -- not immediate and funct7 = SUB
          alu_operation_v := alu_cmd_sub_c;
        else
          alu_operation_v := alu_cmd_add_c;
        end if;
      when funct3_sll_c  => alu_operation_v := alu_cmd_shift_c; -- SLL(I)
      when funct3_slt_c  => alu_operation_v := alu_cmd_slt_c;   -- SLT(I)
      when funct3_sltu_c => alu_operation_v := alu_cmd_slt_c;   -- SLTU(I)
      when funct3_xor_c  => alu_operation_v := alu_cmd_xor_c;   -- XOR(I)
      when funct3_sr_c   => alu_operation_v := alu_cmd_shift_c; -- SRL(I) / SRA(I)
      when funct3_or_c   => alu_operation_v := alu_cmd_or_c;    -- OR(I)
      when funct3_and_c  => alu_operation_v := alu_cmd_and_c;   -- AND(I)
      when others        => alu_operation_v := (others => '0'); -- undefined
    end case;

    -- is rd = r0? --
    rd_is_r0_v := '0';
    if (execute_engine.i_reg(instr_rd_msb_c downto instr_rd_lsb_c) = "00000") then
      rd_is_r0_v := '1';
    end if;

    -- is rs1 = r0? --
    rs1_is_r0_v := '0';
    if (execute_engine.i_reg(instr_rs1_msb_c downto instr_rs1_lsb_c) = "00000") then
      rs1_is_r0_v := '1';
    end if;

    -- state machine --
    case execute_engine.state is

      when SYS_WAIT => -- Delay cycle (used to wait for side effects to kick in)
      -- ------------------------------------------------------------
        execute_engine.state_nxt <= DISPATCH;

       when DISPATCH => -- Get new command from instruction prefetch buffer (IPB)
       -- ------------------------------------------------------------
         if (ipb.avail = '1') then -- instruction available?
           ipb.re <= '1';
           trap_ctrl.instr_ma    <= ipb.rdata(33);
           trap_ctrl.instr_be    <= ipb.rdata(34);
           if (trap_ctrl.env_start = '1') or (ipb.rdata(33) = '1') or (ipb.rdata(34) = '1') then -- exception/interrupt?
             execute_engine.state_nxt <= TRAP;
           else
             execute_engine.is_ci_nxt <= ipb.rdata(32); -- flag to indicate this is a compressed instruction beeing executed
             execute_engine.i_reg_nxt <= ipb.rdata(31 downto 0);
             execute_engine.pc_nxt    <= ipb.raddr(data_width_c-1 downto 1) & '0'; -- the PC according to the current instruction
             execute_engine.state_nxt <= EXECUTE;
           end if;
         end if;

      when TRAP => -- Start trap environment (also used as cpu sleep state)
      -- ------------------------------------------------------------
        fetch_engine.reset <= '1';
        if (trap_ctrl.env_start = '1') then
          trap_ctrl.env_start_ack  <= '1';
          execute_engine.pc_nxt    <= csr.mtvec(data_width_c-1 downto 1) & '0';
          execute_engine.state_nxt <= SYS_WAIT;
        end if;

      when EXECUTE => -- Decode and execute instruction
      -- ------------------------------------------------------------
        case execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) is

          when opcode_alu_c | opcode_alui_c => -- ALU operation
          -- ------------------------------------------------------------
            ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- use RS1 as ALU.OPA
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= alu_immediate_v; -- use IMM as ALU.OPB for immediate operations
            ctrl_nxt(ctrl_alu_opc_mux_c)     <= not alu_immediate_v;
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_operation_v; -- actual ALU operation
            ctrl_nxt(ctrl_rf_in_mux_msb_c downto ctrl_rf_in_mux_lsb_c) <= "00"; -- RF input = ALU result
            -- multi cycle alu operation? --
            if (alu_operation_v = alu_cmd_shift_c) or -- shift operation
               ((CPU_EXTENSION_RISCV_M = true) and (execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) = opcode_alu_c) and
                (execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) = "0000001")) then -- MULDIV?
              execute_engine.state_nxt <= ALU_WAIT;
            else
              ctrl_nxt(ctrl_rf_wb_en_c) <= '1'; -- valid RF write-back
              execute_engine.state_nxt <= DISPATCH;
            end if;
            -- cp access? --
            if (CPU_EXTENSION_RISCV_M = true) and (execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) = opcode_alu_c) and
               (execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) = "0000001") then -- MULDIV?
              ctrl_nxt(ctrl_cp_use_c) <= '1'; -- use CP
              ctrl_nxt(ctrl_cp_id_msb_c downto ctrl_cp_id_lsb_c) <= cp_sel_muldiv_c; -- muldiv CP
            end if;


          when opcode_lui_c | opcode_auipc_c => -- load upper immediate (add to PC)
          -- ------------------------------------------------------------
            ctrl_nxt(ctrl_rf_clear_rs1_c) <= '1'; -- force RS1 = r0
            if (execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) = opcode_auipc_c) then -- AUIPC
              ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '1'; -- use PC as ALU.OPA
            else -- LUI
              ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- use RS1 as ALU.OPA
            end if;
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- use IMM as ALU.OPB
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_add_c; -- actual ALU operation
            ctrl_nxt(ctrl_rf_in_mux_msb_c downto ctrl_rf_in_mux_lsb_c) <= "00"; -- RF input = ALU result
            ctrl_nxt(ctrl_rf_wb_en_c) <= '1'; -- valid RF write-back
            execute_engine.state_nxt <= DISPATCH;

          when opcode_load_c | opcode_store_c => -- load/store
          -- ------------------------------------------------------------
            ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- use RS1 as ALU.OPA
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- use IMM as ALU.OPB
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_add_c; -- actual ALU operation
            ctrl_nxt(ctrl_bus_mar_we_c) <= '1'; -- write to MAR
            ctrl_nxt(ctrl_bus_mdo_we_c) <= '1'; -- write to MDO (only relevant for stores)
            if (fetch_engine.state /= IFETCH_0) then
              if (execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) = opcode_load_c) then -- LOAD
                execute_engine.state_nxt <= LOAD;
              else -- STORE
                execute_engine.state_nxt <= STORE;
              end if;
            end if;

          when opcode_branch_c => -- branch instruction
          -- ------------------------------------------------------------
            ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '1'; -- use PC as ALU.OPA
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- use IMM as ALU.OPB
            ctrl_nxt(ctrl_alu_opc_mux_c)     <= '1'; -- use RS2 as ALU.OPC
            execute_engine.state_nxt         <= BRANCH;

          when opcode_jal_c | opcode_jalr_c => -- jump and link (with register)
          -- ------------------------------------------------------------
            -- compute target address --
            if (execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) = opcode_jal_c) then -- JAL
              ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '1'; -- use PC as ALU.OPA
            else -- JALR
              ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- use RS1 as ALU.OPA
            end if;
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- use IMM as ALU.OPB
            -- save return address --
            ctrl_nxt(ctrl_rf_in_mux_msb_c downto ctrl_rf_in_mux_lsb_c) <= "10"; -- RF input = current PC
            ctrl_nxt(ctrl_rf_wb_en_c) <= '1'; -- valid RF write-back
            --
            execute_engine.is_jump_nxt <= '1'; -- this is a jump operation
            execute_engine.state_nxt   <= BRANCH;

          when opcode_fence_c => -- fence operations
          -- ------------------------------------------------------------
            if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_fencei_c) and (CPU_EXTENSION_RISCV_Zifencei = true) then -- FENCE.I
              fetch_engine.reset       <= '1';
              execute_engine.pc_nxt    <= execute_engine.next_pc;
              execute_engine.state_nxt <= SYS_WAIT;
            else
              execute_engine.state_nxt <= DISPATCH;
            end if;

          when opcode_syscsr_c => -- system/csr access
          -- ------------------------------------------------------------
            if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrw_c) or
               (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrwi_c) then
              csr.re_nxt <= not rd_is_r0_v; -- only read CSR if not writing to zero_reg
            else
              csr.re_nxt <= '1'; -- always read CSR
            end if;
            --
            if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_env_c) then -- system
              case execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) is
                when x"000" => -- ECALL
                  trap_ctrl.env_call <= '1';
                  execute_engine.state_nxt <= SYS_WAIT;
                when x"001" => -- EBREAK
                  trap_ctrl.break_point <= '1';
                  execute_engine.state_nxt <= SYS_WAIT;
                when x"302" => -- MRET
                  trap_ctrl.env_end        <= '1';
                  execute_engine.pc_nxt    <= csr.mepc(data_width_c-1 downto 1) & '0';
                  fetch_engine.reset       <= '1';
                  execute_engine.state_nxt <= SYS_WAIT;
                when x"105" => -- WFI = "CPU sleep"
                  execute_engine.state_nxt <= TRAP;
                when others => -- undefined
                  NULL;
              end case;
            elsif (CPU_EXTENSION_RISCV_Zicsr = true) then -- CSR access
              execute_engine.state_nxt <= CSR_ACCESS;
            else
              execute_engine.state_nxt <= DISPATCH;
            end if;

          when others => -- undefined
          -- ------------------------------------------------------------
            execute_engine.state_nxt <= DISPATCH;

        end case;

      when CSR_ACCESS => -- write CSR data to RF, write ALU.res to CSR
      -- ------------------------------------------------------------
        ctrl_nxt(ctrl_alu_opa_mux_msb_c) <= '0'; -- default
        ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- default
        ctrl_nxt(ctrl_alu_opb_mux_msb_c) <= '0'; -- default
        ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '0'; -- default
        case execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) is
          -- register operations --
          when funct3_csrrw_c => -- CSRRW
            ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- OPA = rs1
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '0'; -- OPB = rs2
            ctrl_nxt(ctrl_rf_clear_rs2_c)    <= '1'; -- rs2 = 0
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_add_c; -- actual ALU operation = ADD
            csr.we_nxt <= '1'; -- always write CSR
          when funct3_csrrs_c => -- CSRRS
            ctrl_nxt(ctrl_alu_opa_mux_msb_c) <= '1'; -- OPA = csr
            ctrl_nxt(ctrl_alu_opb_mux_msb_c) <= '1'; -- OPB = crs1
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_or_c; -- actual ALU operation = OR
            csr.we_nxt <= not rs1_is_r0_v; -- write CSR if rs1 is not zero_reg
          when funct3_csrrc_c => -- CSRRC
            ctrl_nxt(ctrl_alu_opa_mux_msb_c) <= '1'; -- OPA = csr
            ctrl_nxt(ctrl_alu_opb_mux_msb_c) <= '1'; -- OPB = rs1
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_bitc_c; -- actual ALU operation = bit clear
            csr.we_nxt <= not rs1_is_r0_v; -- write CSR if rs1 is not zero_reg
          -- immediate operations --
          when funct3_csrrwi_c => -- CSRRWI
            ctrl_nxt(ctrl_alu_opa_mux_lsb_c) <= '0'; -- OPA = rs1
            ctrl_nxt(ctrl_rf_clear_rs1_c)    <= '1'; -- rs1 = 0
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- OPB = immediate
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_add_c; -- actual ALU operation = ADD
            csr.we_nxt <= '1'; -- always write CSR
          when funct3_csrrsi_c => -- CSRRSI
            ctrl_nxt(ctrl_alu_opa_mux_msb_c) <= '1'; -- OPA = csr
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- OPB = immediate
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_or_c; -- actual ALU operation = OR
            csr.we_nxt <= not rs1_is_r0_v; -- write CSR if UIMM5 is not zero (bits from rs1 filed)
          when funct3_csrrci_c => -- CSRRCI
            ctrl_nxt(ctrl_alu_opa_mux_msb_c) <= '1'; -- OPA = csr
            ctrl_nxt(ctrl_alu_opb_mux_lsb_c) <= '1'; -- OPB = immediate
            ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_cmd_bitc_c; -- actual ALU operation = bit clear
            csr.we_nxt <= not rs1_is_r0_v; -- write CSR if UIMM5 is not zero (bits from rs1 filed)
          when others => -- undefined
            NULL;
        end case;
        -- RF write back --
        ctrl_nxt(ctrl_rf_in_mux_msb_c downto ctrl_rf_in_mux_lsb_c) <= "11"; -- RF input = CSR output register
        ctrl_nxt(ctrl_rf_wb_en_c) <= '1'; -- valid RF write-back
        execute_engine.state_nxt <= DISPATCH; -- FIXME should be SYS_WAIT? have another cycle to let side-effects kick in

      when ALU_WAIT => -- wait for multi-cycle ALU operation to finish
      -- ------------------------------------------------------------
        ctrl_nxt(ctrl_alu_cmd2_c downto ctrl_alu_cmd0_c) <= alu_operation_v; -- actual ALU operation
        ctrl_nxt(ctrl_rf_in_mux_msb_c downto ctrl_rf_in_mux_lsb_c) <= "00"; -- RF input = ALU result
        ctrl_nxt(ctrl_rf_wb_en_c) <= '1'; -- valid RF write-back (write back all the time)
        if (alu_wait_i = '0') then
          execute_engine.state_nxt <= DISPATCH;
        end if;

      when BRANCH => -- update PC for taken branches and jumps
      -- ------------------------------------------------------------
        if (execute_engine.is_jump = '1') or (execute_engine.branch_taken = '1') then
          execute_engine.pc_nxt <= alu_add_i(data_width_c-1 downto 1) & '0';
          fetch_engine.reset    <= '1';
        end if;
        execute_engine.state_nxt <= SYS_WAIT;

      when LOAD => -- trigger memory read request
      -- ------------------------------------------------------------
        ctrl_nxt(ctrl_bus_rd_c)  <= '1'; -- fast read request
        execute_engine.state_nxt <= LOADSTORE_0;

      when STORE => -- trigger memory write request
      -- ------------------------------------------------------------
        ctrl_nxt(ctrl_bus_wr_c)  <= '1'; -- fast write request
        execute_engine.state_nxt <= LOADSTORE_0;

      when LOADSTORE_0 => -- memory latency
      -- ------------------------------------------------------------
        ctrl_nxt(ctrl_bus_mdi_we_c) <= '1'; -- write input data to MDI (only relevant for LOAD)
        execute_engine.state_nxt <= LOADSTORE_1;

      when LOADSTORE_1 => -- wait for bus transaction to finish
      -- ------------------------------------------------------------
        ctrl_nxt(ctrl_bus_mdi_we_c) <= '1'; -- keep writing input data to MDI (only relevant for LOAD)
        ctrl_nxt(ctrl_rf_in_mux_msb_c downto ctrl_rf_in_mux_lsb_c) <= "01"; -- RF input = memory input (only relevant for LOAD)
        if (ma_load_i = '1') or (be_load_i = '1') or (ma_store_i = '1') or (be_store_i = '1') then -- abort if exception
          execute_engine.state_nxt <= SYS_WAIT;
        elsif (bus_wait_i = '0') then -- wait here for bus to finish transaction
          if (execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) = opcode_load_c) then -- LOAD?
            ctrl_nxt(ctrl_rf_wb_en_c) <= '1'; -- valid RF write-back
          end if;
          execute_engine.state_nxt <= DISPATCH;
        end if;

      when others => -- undefined
      -- ------------------------------------------------------------
        execute_engine.state_nxt <= SYS_WAIT;

    end case;
  end process execute_engine_fsm_comb;


  -- Illegal Instruction Check --------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  illegal_instruction_check: process(execute_engine, csr, ctrl_nxt, ci_illegal)
  begin
    -- illegal instructions are checked in the EXECUTE stage
    -- the execute engine will only commit valid instructions
    if (execute_engine.state = EXECUTE) then
      -- defaults --
      illegal_instruction <= '0';
      illegal_register    <= '0';
      illegal_compressed  <= '0';

      -- check if using reg >= 16 for E-CPUs --
--if (CPU_EXTENSION_RISCV_E = true) then
--  illegal_register <= ctrl_nxt(ctrl_rf_rd_adr4_c) or ctrl_nxt(ctrl_rf_rs2_adr4_c) or ctrl_nxt(ctrl_rf_rs1_adr4_c);
--else
--  illegal_register <= '0';
--end if;

      -- check instructions --
      case execute_engine.i_reg(instr_opcode_msb_c downto instr_opcode_lsb_c) is

        -- OPCODE check sufficient: LUI, UIPC, JAL --
        when opcode_lui_c | opcode_auipc_c | opcode_jal_c =>
          illegal_instruction <= '0';

        when opcode_alui_c => -- check ALUI funct7
          if ((execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_sll_c) and
              (execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) /= "0000000")) or -- shift logical left
             ((execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_sr_c) and
              ((execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) /= "0000000") and
               (execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) /= "0100000"))) then -- shift right
            illegal_instruction <= '1';
          else
            illegal_instruction <= '0';
          end if;
      
        when opcode_load_c => -- check LOAD funct3
          if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_lb_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_lh_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_lw_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_lbu_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_lhu_c) then
            illegal_instruction <= '0';
          else
            illegal_instruction <= '1';
          end if;
      
        when opcode_store_c => -- check STORE funct3
          if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_sb_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_sh_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_sw_c) then
            illegal_instruction <= '0';
          else
            illegal_instruction <= '1';
          end if;

        when opcode_branch_c => -- check BRANCH funct3
          if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_beq_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_bne_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_blt_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_bge_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_bltu_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_bgeu_c) then
            illegal_instruction <= '0';
          else
            illegal_instruction <= '1';
          end if;

        when opcode_jalr_c => -- check JALR funct3
          if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = "000") then
            illegal_instruction <= '0';
          else
            illegal_instruction <= '1';
          end if;

        when opcode_alu_c => -- check ALU funct3 & funct7
          if (execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) = "0000001") then -- MULDIV
            if (CPU_EXTENSION_RISCV_M = false) then -- not implemented
              illegal_instruction <= '1';
            end if;
          elsif ((execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_subadd_c) or
                 (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_sr_c)) and -- ADD/SUB or SRA/SRL check
                ((execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) /= "0000000") and
                 (execute_engine.i_reg(instr_funct7_msb_c downto instr_funct7_lsb_c) /= "0100000")) then -- ADD/SUB or SRA/SRL select
            illegal_instruction <= '1';
          else
            illegal_instruction <= '0';
          end if;

        when opcode_fence_c => -- fence instructions --
          if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_fencei_c) and (CPU_EXTENSION_RISCV_Zifencei = true) then -- FENCE.I
            illegal_instruction <= '0';
          elsif (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_fence_c) then -- FENCE
            illegal_instruction <= '0';
          else
            illegal_instruction <= '1';
          end if;

        when opcode_syscsr_c => -- check system instructions --
          -- CSR access --
          if (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrw_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrs_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrc_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrwi_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrsi_c) or
             (execute_engine.i_reg(instr_funct3_msb_c downto instr_funct3_lsb_c) = funct3_csrrci_c) then
            -- valid CSR? --
            if (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"300") or -- mstatus
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"301") or -- misa
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"304") or -- mie
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"305") or -- mtvev
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"340") or -- mscratch
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"341") or -- mepc
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"342") or -- mcause
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"343") or -- mtval
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"344") or -- mip
               --
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"c00") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- cycle
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"c01") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- time
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"c02") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- instret
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"c80") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- cycleh
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"c81") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- timeh
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"c82") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- instreth
               --
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"b00") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- mcycle
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"b02") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- minstret
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"b80") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- mcycleh
               ((execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"b82") and (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true)) or -- minstreth
               --
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"f13") or -- mimpid
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"f14") or -- mhartid
               --
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"fc0") or -- mfeatures
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"fc1") or -- mclock
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"fc4") or -- mispacebase
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"fc5") or -- mispacesize
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"fc6") or -- mdspacebase
               (execute_engine.i_reg(instr_funct12_msb_c downto instr_funct12_lsb_c) = x"fc7") then -- mdspacesize
              illegal_instruction <= '0';
            else
              illegal_instruction <= '1';
            end if;

          -- ecall, ebreak, mret, wfi --
          elsif (execute_engine.i_reg(instr_rd_msb_c  downto instr_rd_lsb_c)  = "00000") and
                (execute_engine.i_reg(instr_rs1_msb_c downto instr_rs1_lsb_c) = "00000") then
            if (execute_engine.i_reg(instr_funct12_msb_c  downto instr_funct12_lsb_c) = "000000000000") or -- ECALL
               (execute_engine.i_reg(instr_funct12_msb_c  downto instr_funct12_lsb_c) = "000000000001") or -- EBREAK 
               (execute_engine.i_reg(instr_funct12_msb_c  downto instr_funct12_lsb_c) = "001100000010") or -- MRET
               (execute_engine.i_reg(instr_funct12_msb_c  downto instr_funct12_lsb_c) = "000100000101") then -- WFI
              illegal_instruction <= '0';
            else
              illegal_instruction <= '1';
            end if;
          else
            illegal_instruction <= '1';
          end if;

        when others => -- compressed instruction or undefined instruction
          if (execute_engine.i_reg(1 downto 0) = "11") then -- undefined/unimplemented opcode
            illegal_instruction <= '1';
          else -- compressed instruction: illegal or disabled / not implemented
            illegal_compressed <= ci_illegal;
          end if;

      end case;
    else
      illegal_instruction <= '0';
      illegal_register    <= '0';
      illegal_compressed  <= '0';
    end if;
  end process illegal_instruction_check;

  -- any illegal condition? --
  trap_ctrl.instr_il <= illegal_instruction or illegal_register or illegal_compressed;


-- ****************************************************************************************************************************
-- Exception and Interrupt Control
-- ****************************************************************************************************************************


  -- Trap Controller ------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  trap_controller: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      trap_ctrl.exc_buf   <= (others => '0');
      trap_ctrl.irq_buf   <= (others => '0');
      trap_ctrl.exc_ack   <= '0';
      trap_ctrl.irq_ack   <= (others => '0');
      trap_ctrl.cause     <= (others => '0');
      trap_ctrl.exc_src   <= (others => '0');
      trap_ctrl.env_start <= '0';
    elsif rising_edge(clk_i) then
      if (CPU_EXTENSION_RISCV_Zicsr = true) then
        -- exception buffer: misaligned load/store/instruction address
        trap_ctrl.exc_buf(exception_lalign_c)    <= (trap_ctrl.exc_buf(exception_lalign_c)    or ma_load_i)             and (not trap_ctrl.exc_ack);
        trap_ctrl.exc_buf(exception_salign_c)    <= (trap_ctrl.exc_buf(exception_salign_c)    or ma_store_i)            and (not trap_ctrl.exc_ack);
        trap_ctrl.exc_buf(exception_ialign_c)    <= (trap_ctrl.exc_buf(exception_ialign_c)    or trap_ctrl.instr_ma)    and (not trap_ctrl.exc_ack);
        -- exception buffer: load/store/instruction bus access error
        trap_ctrl.exc_buf(exception_laccess_c)   <= (trap_ctrl.exc_buf(exception_laccess_c)   or be_load_i)             and (not trap_ctrl.exc_ack);
        trap_ctrl.exc_buf(exception_saccess_c)   <= (trap_ctrl.exc_buf(exception_saccess_c)   or be_store_i)            and (not trap_ctrl.exc_ack);
        trap_ctrl.exc_buf(exception_iaccess_c)   <= (trap_ctrl.exc_buf(exception_iaccess_c)   or trap_ctrl.instr_be)    and (not trap_ctrl.exc_ack);
        -- exception buffer: illegal instruction / env call / break point
        trap_ctrl.exc_buf(exception_m_envcall_c) <= (trap_ctrl.exc_buf(exception_m_envcall_c) or trap_ctrl.env_call)    and (not trap_ctrl.exc_ack);
        trap_ctrl.exc_buf(exception_break_c)     <= (trap_ctrl.exc_buf(exception_break_c)     or trap_ctrl.break_point) and (not trap_ctrl.exc_ack);
        trap_ctrl.exc_buf(exception_iillegal_c)  <= (trap_ctrl.exc_buf(exception_iillegal_c)  or trap_ctrl.instr_il)    and (not trap_ctrl.exc_ack);
        -- interrupt buffer: machine software/external/timer interrupt
        trap_ctrl.irq_buf(interrupt_msw_irq_c)   <= csr.mie_msie and (trap_ctrl.irq_buf(interrupt_msw_irq_c)   or csr.mip_msip) and (not trap_ctrl.irq_ack(interrupt_msw_irq_c));
        trap_ctrl.irq_buf(interrupt_mext_irq_c)  <= csr.mie_meie and (trap_ctrl.irq_buf(interrupt_mext_irq_c)  or clic_irq_i)   and (not trap_ctrl.irq_ack(interrupt_mext_irq_c));
        trap_ctrl.irq_buf(interrupt_mtime_irq_c) <= csr.mie_mtie and (trap_ctrl.irq_buf(interrupt_mtime_irq_c) or mtime_irq_i)  and (not trap_ctrl.irq_ack(interrupt_mtime_irq_c));

        -- trap control --
        if (trap_ctrl.env_start = '0') then -- no started trap handler
          if (trap_ctrl.exc_fire = '1') or ((trap_ctrl.irq_fire = '1') and
             ((execute_engine.state = EXECUTE) or (execute_engine.state = TRAP))) then -- exception/IRQ detected!
            trap_ctrl.cause     <= trap_ctrl.cause_nxt;   -- capture source ID for program
            trap_ctrl.exc_src   <= trap_ctrl.exc_buf;     -- capture exception source for hardware
            trap_ctrl.exc_ack   <= '1';                   -- clear execption
            trap_ctrl.irq_ack   <= trap_ctrl.irq_ack_nxt; -- capture and clear with interrupt ACK mask
            trap_ctrl.env_start <= '1';                   -- now we want to start the trap handler
          end if;
        else -- trap waiting to get started
          if (trap_ctrl.env_start_ack = '1') then -- start of trap handler acknowledged by execution engine
            trap_ctrl.exc_ack   <= '0';
            trap_ctrl.irq_ack   <= (others => '0');
            trap_ctrl.env_start <= '0';
          end if;
        end if;
      end if;
    end if;
  end process trap_controller;

  -- any exception/interrupt? --
  trap_ctrl.exc_fire <= or_all_f(trap_ctrl.exc_buf); -- classic exceptions (faults/traps) cannot be masked
  trap_ctrl.irq_fire <= or_all_f(trap_ctrl.irq_buf) and csr.mstatus_mie; -- classic interrupts can be enabled/disabled


  -- Trap Priority Detector -----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  trap_priority: process(trap_ctrl)
  begin
    -- defaults --
    trap_ctrl.cause_nxt   <= (others => '0');
    trap_ctrl.irq_ack_nxt <= (others => '0');

    -- the following traps are caused by asynchronous exceptions (-> interrupts)
    -- here we do need an acknowledge mask since several sources can trigger at once

    -- interrupt: 1.11 machine external interrupt --
    if (trap_ctrl.irq_buf(interrupt_mext_irq_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '1';
      trap_ctrl.cause_nxt(3 downto 0) <= "1011";
      trap_ctrl.irq_ack_nxt(interrupt_mext_irq_c) <= '1';

    -- interrupt: 1.7 machine timer interrupt --
    elsif (trap_ctrl.irq_buf(interrupt_mtime_irq_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '1';
      trap_ctrl.cause_nxt(3 downto 0) <= "0111";
      trap_ctrl.irq_ack_nxt(interrupt_mtime_irq_c) <= '1';

    -- interrupt: 1.3 machine SW interrupt --
    elsif (trap_ctrl.irq_buf(interrupt_msw_irq_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '1';
      trap_ctrl.cause_nxt(3 downto 0) <= "0011";
      trap_ctrl.irq_ack_nxt(interrupt_msw_irq_c) <= '1';


    -- the following traps are caused by synchronous exceptions
    -- here we do not need an acknowledge mask since only one exception (the one
    -- with highest priority) can trigger at once

    -- trap/fault: 0.0 instruction address misaligned --
    elsif (trap_ctrl.exc_buf(exception_ialign_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0000";

    -- trap/fault: 0.1 instruction access fault --
    elsif (trap_ctrl.exc_buf(exception_iaccess_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0001";

    -- trap/fault: 0.2 illegal instruction --
    elsif (trap_ctrl.exc_buf(exception_iillegal_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0010";


    -- trap/fault: 0.11 environment call from M-mode --
    elsif (trap_ctrl.exc_buf(exception_m_envcall_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "1011";

    -- trap/fault: 0.3 breakpoint --
    elsif (trap_ctrl.exc_buf(exception_break_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0011";


    -- trap/fault: 0.6 store address misaligned -
    elsif (trap_ctrl.exc_buf(exception_salign_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0110";

    -- trap/fault: 0.4 load address misaligned --
    elsif (trap_ctrl.exc_buf(exception_lalign_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0100";

    -- trap/fault: 0.7 store access fault --
    elsif (trap_ctrl.exc_buf(exception_saccess_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0111";

    -- trap/fault: 0.5 load access fault --
    elsif (trap_ctrl.exc_buf(exception_laccess_c) = '1') then
      trap_ctrl.cause_nxt(data_width_c-1) <= '0';
      trap_ctrl.cause_nxt(3 downto 0) <= "0101";

    -- undefined / not implemented --
    else
      trap_ctrl.cause_nxt   <= (others => '0');
      trap_ctrl.irq_ack_nxt <= (others => '0');
    end if;
  end process trap_priority;
  

-- ****************************************************************************************************************************
-- Control and Status Registers (CSRs)
-- ****************************************************************************************************************************

  -- CSR CPU Access -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  csr_cpu_acc: process(clk_i)
  begin
    if rising_edge(clk_i) then
      csr.we <= csr.we_nxt;
      csr.re <= csr.re_nxt;
    end if;
  end process csr_cpu_acc;


  -- Control and Status Registers Write Access ----------------------------------------------
  -- -------------------------------------------------------------------------------------------
  csr_write_access: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      csr.mstatus_mie  <= '0';
      csr.mstatus_mpie <= '0';
      csr.mie_msie     <= '0';
      csr.mie_meie     <= '0';
      csr.mie_mtie     <= '0';
      csr.mtvec        <= (others => '0');
      csr.mtval        <= (others => '0');
      csr.mepc         <= (others => '0');
      csr.mip_msip     <= '0';
    elsif rising_edge(clk_i) then
      if (CPU_EXTENSION_RISCV_Zicsr = true) then
        -- defaults --
        csr.mip_msip <= '0';

        -- register that can be modified by user --
        if (csr.we = '1') then -- manual update

          -- Machine CSRs: Standard read/write
          if (execute_engine.i_reg(31 downto 28) = x"3") then
            -- machine trap setup --
            if (execute_engine.i_reg(27 downto 24) = x"0") then
              if (execute_engine.i_reg(23 downto 20) = x"0") then -- R/W: mstatus - machine status register
                csr.mstatus_mie  <= csr_wdata_i(03);
                csr.mstatus_mpie <= csr_wdata_i(07);
              end if;
              if (execute_engine.i_reg(23 downto 20) = x"4") then -- R/W: mie - machine interrupt-enable register
                csr.mie_msie <= csr_wdata_i(03); -- SW IRQ enable
                csr.mie_mtie <= csr_wdata_i(07); -- TIMER IRQ enable
                csr.mie_meie <= csr_wdata_i(11); -- EXT IRQ enable
              end if;
              if (execute_engine.i_reg(23 downto 20) = x"5") then -- R/W: mtvec - machine trap-handler base address (for ALL exceptions)
                csr.mtvec <= csr_wdata_i;
              end if;
            end if;
            -- machine trap handling --
            if (execute_engine.i_reg(27 downto 24) = x"4") then
              case execute_engine.i_reg(23 downto 20) is
                when x"0" => -- R/W: mscratch - machine scratch register
                  csr.mscratch <= csr_wdata_i;
                when x"1" => -- R/W: mepc - machine exception program counter
                  csr.mepc <= csr_wdata_i;
                when x"2" => -- R/W: mcause - machine trap cause
                  csr.mcause <= csr_wdata_i;
                when x"3" => -- R/W: mtval - machine bad address or instruction
                  csr.mtval <= csr_wdata_i;
                when x"4" => -- R/W: mip - machine interrupt pending
                  csr.mip_msip <= csr_wdata_i(03); -- manual SW IRQ trigger
                when others =>
                  NULL;
              end case;
              
-- FIXME remove code below
              --if (execute_engine.i_reg(23 downto 20) = x"0") then -- R/W: mscratch - machine scratch register
              --  csr.mscratch <= csr_wdata_i;
              --end if;
              --if (execute_engine.i_reg(23 downto 20) = x"1") then -- R/W: mepc - machine exception program counter
              --  csr.mepc <= csr_wdata_i;
              --end if;
              --if (execute_engine.i_reg(23 downto 20) = x"2") then -- R/W: mcause - machine trap cause
              --  csr.mcause <= csr_wdata_i;
              --end if;
              --if (execute_engine.i_reg(23 downto 20) = x"3") then -- R/W: mtval - machine bad address or instruction
              --  csr.mtval <= csr_wdata_i;
              --end if;
              --if (execute_engine.i_reg(23 downto 20) = x"4") then -- R/W: mip - machine interrupt pending
              --  csr.mip_msip <= csr_wdata_i(03); -- manual SW IRQ trigger
              --end if;
            end if;
          end if;

        else -- automatic update by hardware

          -- machine exception PC & exception value register --
          if (trap_ctrl.env_start_ack = '1') then -- trap handler started?
            csr.mcause <= trap_ctrl.cause;
            if (csr.mcause(data_width_c-1) = '1') then -- for INTERRUPTS only
              csr.mepc  <= execute_engine.pc(data_width_c-1 downto 1) & '0'; -- this is the CURRENT pc = interrupted instruction
              csr.mtval <= (others => '0'); -- mtval not defined for interrupts
            else -- for EXCEPTIONS (according to their priority)
              csr.mepc <= execute_engine.last_pc(data_width_c-1 downto 1) & '0'; -- this is the LAST pc = last executed instruction
              if ((trap_ctrl.exc_src(exception_iaccess_c) or trap_ctrl.exc_src(exception_ialign_c)) = '1') then -- instruction access error OR misaligned instruction
                csr.mtval <= execute_engine.pc(data_width_c-1 downto 1) & '0'; -- address of faulting instruction
              elsif (trap_ctrl.exc_src(exception_iillegal_c) = '1') then -- illegal instruction
                csr.mtval <= execute_engine.i_reg; -- the faulting instruction itself
              else -- load/store msialignments/access errors
                csr.mtval <= mar_i; -- faulting data access address
              end if;
            end if;
          end if;

          -- context switch in mstatus --
          if (trap_ctrl.env_start_ack = '1') then -- actually entering trap
            csr.mstatus_mie <= '0';
            if (csr.mstatus_mpie = '0') then -- prevent loosing the prev MIE state in nested traps
              csr.mstatus_mpie <= csr.mstatus_mie;
            end if;
          elsif (trap_ctrl.env_end = '1') then -- return from exception
            csr.mstatus_mie <= csr.mstatus_mpie;
          end if;

        end if;
      end if;
    end if;
  end process csr_write_access;


  -- Control and Status Registers Read Access -----------------------------------------------
  -- -------------------------------------------------------------------------------------------
  csr_read_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      csr_rdata_o <= (others => '0'); -- default
      if (CPU_EXTENSION_RISCV_Zicsr = true) then -- implement CSR access at all?
        if (csr.re = '1') then
          case execute_engine.i_reg(31 downto 20) is
            -- machine trap setup --
            when x"300" => -- R/W: mstatus - machine status register
              csr_rdata_o(03) <= csr.mstatus_mie; -- MIE
              csr_rdata_o(07) <= csr.mstatus_mpie; -- MPIE
              csr_rdata_o(11) <= '1'; -- MPP low
              csr_rdata_o(12) <= '1'; -- MPP high
            when x"301" => -- R/W: misa - ISA and extensions
              csr_rdata_o(02) <= bool_to_ulogic_f(CPU_EXTENSION_RISCV_C);     -- C CPU extension
              csr_rdata_o(04) <= bool_to_ulogic_f(CPU_EXTENSION_RISCV_E);     -- E CPU extension
              csr_rdata_o(08) <= not bool_to_ulogic_f(CPU_EXTENSION_RISCV_E); -- I CPU extension (if not E)
              csr_rdata_o(12) <= bool_to_ulogic_f(CPU_EXTENSION_RISCV_M);     -- M CPU extension
              csr_rdata_o(25) <= bool_to_ulogic_f(CPU_EXTENSION_RISCV_Zicsr) and bool_to_ulogic_f(CPU_EXTENSION_RISCV_Zifencei); -- Z CPU extension
              csr_rdata_o(30) <= '1'; -- 32-bit architecture (MXL lo)
              csr_rdata_o(31) <= '0'; -- 32-bit architecture (MXL hi)
            when x"304" => -- R/W: mie - machine interrupt-enable register
              csr_rdata_o(03) <= csr.mie_msie; -- software IRQ enable
              csr_rdata_o(07) <= csr.mie_mtie; -- timer IRQ enable
              csr_rdata_o(11) <= csr.mie_meie; -- external IRQ enable
            when x"305" => -- R/W: mtvec - machine trap-handler base address (for ALL exceptions)
              csr_rdata_o <= csr.mtvec;
            -- machine trap handling --
            when x"340" => -- R/W: mscratch - machine scratch register
              csr_rdata_o <= csr.mscratch;
            when x"341" => -- R/W: mepc - machine exception program counter
              csr_rdata_o <= csr.mepc;
            when x"342" => -- R/W: mcause - machine trap cause
              csr_rdata_o <= csr.mcause;
            when x"343" => -- R/W: mtval - machine bad address or instruction
              csr_rdata_o <= csr.mtval;
            when x"344" => -- R/W: mip - machine interrupt pending
              csr_rdata_o(03) <= trap_ctrl.irq_buf(interrupt_msw_irq_c);
              csr_rdata_o(07) <= trap_ctrl.irq_buf(interrupt_mtime_irq_c);
              csr_rdata_o(11) <= trap_ctrl.irq_buf(interrupt_mext_irq_c);
            -- counter and timers --
            when x"c00" | x"c01" | x"b00" => -- R/-: cycle/time/mcycle: Cycle counter LOW / Timer LOW
              csr_rdata_o <= csr.cycle(31 downto 0);
            when x"c02" | x"b02" => -- R/-: instret/minstret: Instructions-retired counter LOW
              csr_rdata_o <= csr.instret(31 downto 0);
            when x"c80" | x"c81" | x"b80" => -- R/-: cycleh/timeh/mcycleh: Cycle counter HIGH / Timer HIGH
              csr_rdata_o <= csr.cycleh;
            when x"c82" | x"b82" => -- R/-: instreth/minstreth: Instructions-retired counter HIGH
              csr_rdata_o <= csr.instreth;
            -- machine information registers --
            when x"f13" => -- R/-: mimpid - implementation ID / version
              csr_rdata_o <= hw_version_c;
            when x"f14" => -- R/-: mhartid - hardware thread ID
              csr_rdata_o <= HART_ID;
            -- CUSTOM read-only machine CSRs --
            when x"fc0" => -- R/-: mfeatures - implemented processor devices/features
              csr_rdata_o(00) <= bool_to_ulogic_f(BOOTLOADER_USE);   -- implement processor-internal bootloader?
              csr_rdata_o(01) <= bool_to_ulogic_f(MEM_EXT_USE);      -- implement external memory bus interface?
              csr_rdata_o(02) <= bool_to_ulogic_f(MEM_INT_IMEM_USE); -- implement processor-internal instruction memory?
              csr_rdata_o(03) <= bool_to_ulogic_f(MEM_INT_IMEM_ROM); -- implement processor-internal instruction memory as ROM?
              csr_rdata_o(04) <= bool_to_ulogic_f(MEM_INT_DMEM_USE); -- implement processor-internal data memory?
              csr_rdata_o(05) <= bool_to_ulogic_f(CSR_COUNTERS_USE); -- implement RISC-V (performance) counter?
              --
              csr_rdata_o(16) <= bool_to_ulogic_f(IO_GPIO_USE);      -- implement general purpose input/output port unit (GPIO)?
              csr_rdata_o(17) <= bool_to_ulogic_f(IO_MTIME_USE);     -- implement machine system timer (MTIME)?
              csr_rdata_o(18) <= bool_to_ulogic_f(IO_UART_USE);      -- implement universal asynchronous receiver/transmitter (UART)?
              csr_rdata_o(19) <= bool_to_ulogic_f(IO_SPI_USE);       -- implement serial peripheral interface (SPI)?
              csr_rdata_o(20) <= bool_to_ulogic_f(IO_TWI_USE);       -- implement two-wire interface (TWI)?
              csr_rdata_o(21) <= bool_to_ulogic_f(IO_PWM_USE);       -- implement pulse-width modulation unit (PWM)?
              csr_rdata_o(22) <= bool_to_ulogic_f(IO_WDT_USE);       -- implement watch dog timer (WDT)?
              csr_rdata_o(23) <= bool_to_ulogic_f(IO_CLIC_USE);      -- implement core local interrupt controller (CLIC)?
              csr_rdata_o(24) <= bool_to_ulogic_f(IO_TRNG_USE);      -- implement true random number generator (TRNG)?
              csr_rdata_o(25) <= bool_to_ulogic_f(IO_DEVNULL_USE);   -- implement dummy device (DEVNULL)?
            when x"fc1" => -- R/-: mclock - processor clock speed
              csr_rdata_o <= std_ulogic_vector(to_unsigned(CLOCK_FREQUENCY, 32));
            when x"fc4" => -- R/-: mispacebase - Base address of instruction memory space
              csr_rdata_o <= MEM_ISPACE_BASE;
            when x"fc5" => -- R/-: mdspacebase - Base address of data memory space
              csr_rdata_o <= MEM_DSPACE_BASE;
            when x"fc6" => -- R/-: mispacesize - Total size of instruction memory space in byte
              csr_rdata_o <= std_ulogic_vector(to_unsigned(MEM_ISPACE_SIZE, 32));
            when x"fc7" => -- R/-: mdspacesize - Total size of data memory space in byte
              csr_rdata_o <= std_ulogic_vector(to_unsigned(MEM_DSPACE_SIZE, 32));
            -- undefined/unavailable --
            when others =>
              csr_rdata_o <= (others => '0'); -- not implemented
          end case;
        end if;
      end if;
    end if;
  end process csr_read_access;


  -- RISC-V Counter CSRs --------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  csr_counters: process(rstn_i, clk_i)
  begin
    if (rstn_i = '0') then
      csr.cycle    <= (others => '0');
      csr.instret  <= (others => '0');
      csr.cycleh   <= (others => '0');
      csr.instreth <= (others => '0');
      cycle_msb    <= '0';
      instret_msb  <= '0';
    elsif rising_edge(clk_i) then
      if (CPU_EXTENSION_RISCV_E = false) and (CSR_COUNTERS_USE = true) then
        -- low word overflow buffers --
        cycle_msb   <= csr.cycle(csr.cycle'left);
        instret_msb <= csr.instret(csr.instret'left);
        -- low word counters --
        csr.cycle <= std_ulogic_vector(unsigned(csr.cycle) + 1);
        if (execute_engine.state_prev /= EXECUTE) and (execute_engine.state = EXECUTE) then
          csr.instret <= std_ulogic_vector(unsigned(csr.instret) + 1);
        end if;
        -- high word counters --
        if ((cycle_msb xor csr.cycle(csr.cycle'left)) = '1') then
          csr.cycleh <= std_ulogic_vector(unsigned(csr.cycleh) + 1);
        end if;
        if ((instret_msb xor csr.instret(csr.instret'left)) = '1') then
          csr.instreth <= std_ulogic_vector(unsigned(csr.instreth) + 1);
        end if;
      end if;
    end if;
  end process csr_counters;


end neorv32_cpu_control_rtl;
