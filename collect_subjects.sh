#!/bin/bash

mkdir subjects && cd subjects
# Verilog
git clone https://github.com/SI-RISCV/e200_opensource.git
git clone https://github.com/cliffordwolf/picorv32.git
git clone https://github.com/T-head-Semi/wujian100_open.git
git clone https://github.com/darklife/darkriscv.git
git clone https://github.com/nvdla/hw.git
git clone https://github.com/mntmn/amiga2000-gfxcard.git
git clone https://github.com/alexforencich/verilog-ethernet.git
git clone https://github.com/analogdevicesinc/hdl.git
git clone https://github.com/ZipCPU/zipcpu.git
git clone https://github.com/VerticalResearchGroup/miaow.git

cd ..
mkdir subjects2 && cd subjects2
# VHDL
git clone https://github.com/ghdl/ghdl.git
git clone https://github.com/aws/aws-fpga.git
git clone https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner.git
git clone https://github.com/hamsternz/FPGA_Webserver.git
git clone https://github.com/newaetech/chipwhisperer.git
git clone https://github.com/stnolting/neorv32.git
git clone https://github.com/asicguy/gplgpu.git
git clone https://github.com/VUnit/vunit.git
git clone https://github.com/ikorb/gcvideo.git
git clone https://github.com/htqin/awesome-model-quantization.git

cd ..
mkdir subjects3 && cd subjects3
# SystemVerilog
git clone https://github.com/lowRISC/opentitan.git
git clone https://github.com/westerndigitalcorporation/swerv_eh1.git
git clone https://github.com/itsFrank/MinecraftHDL.git
git clone https://github.com/rsd-devel/rsd.git
git clone https://github.com/hdl-util/hdmi.git
git clone https://github.com/lowRISC/ibex.git
git clone https://github.com/lowRISC/lowrisc-chip.git
git clone https://github.com/openhwgroup/cv32e40p.git
git clone https://github.com/chipsalliance/Cores-SweRV.git
git clone https://github.com/trivialmips/nontrivial-mips.git
cd ..