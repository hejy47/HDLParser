# 1. HDLParser

<!-- title: HDLParser --> 

****HDLParser**** is a tool of collecting patch-related commits and extracting real bug fixes in hardware description languages (HDLs).
It can automatically collects bug fixing commits from HDL repositories, and parses code changes of patches leveraging hdlConvertor and GumTree. Furthermore, it can measure the redundancy of bug fixing commits.

- [1. HDLParser](#1-hdlparser)
  - [1.1. Introduction](#11-introduction)
  - [1.2. Environment setup](#12-environment-setup)
    - [1.2.1. Requirements](#121-requirements)
    - [1.2.2. Configuration](#122-configuration)
      - [1.2.2.1. HDL AST parsing script](#1221-hdl-ast-parsing-script)
      - [1.2.2.2. Configurating GumTree to surpport HDLs](#1222-configurating-gumtree-to-surpport-hdls)
    - [1.2.3. Execution](#123-execution)
      - [1.2.3.1 Collecting HDL projects from GitHub to create the subjects:](#1231-collecting-hdl-projects-from-github-to-create-the-subjects)
      - [1.2.3.2. Collecting patch-related commits, parsing code changes of patches and measuring commit redundancy](#1232-collecting-patch-related-commits-parsing-code-changes-of-patches-and-measuring-commit-redundancy)
  - [1.3. Scenarios to use HDLParser](#13-scenarios-to-use-hdlparser)
    - [1.3.1. For hardware developers](#131-for-hardware-developers)
    - [1.3.2. For researchers who want to explore APR towards HDLs](#132-for-researchers-who-want-to-explore-apr-towards-hdls)

## 1.1. Introduction

An important problem is the lack of the knowledge on the characteristics of bug fixes in HDLs. Such knowledge will boost the understanding of hardware developers and provide useful insights to new research direction towards automated bug fixing in HDLs.

However, few studies focus on bug fixes of HDLs, which hinders the proposal of APR techniques targeting HDLs. There are mainly two barriers. On one hand, there is lack of research to study the characteristics of bug fixes in HDLs. On the other hand, whether the redundancy assumption still holds in HDLs has not been validated for now.

With such motivation, we propose an automated technique named HDLParser for **analysis of bug fixes in HDLs**. We run HDLParser to make a fine-granularity analysis of patches and validate the redundancy assumption on bug fixing commits. We obtain some interesting findings. All the relevant artifacts are available in this repository.

## 1.2. Environment setup
### 1.2.1. Requirements

+ Ubuntu 20.04
+ Python >= 3.8.0
+ [hdlConvertor](https://github.com/Nic30/hdlConvertor)
+ [GumTree 3.0.0](https://github.com/GumTreeDiff/gumtree)

### 1.2.2. Configuration

#### 1.2.2.1. HDL AST parsing script

The parsing script is used to get the AST of HDL files by hdlConvertor, and then transform the AST to the xml format as the input of GumTree. The steps to use the parsing script are as followed:

* Adding `hdlparser/hdlparser` to the system path
* hdlparser can be used as a standalone tool like this: `hdlparser /path/to/HDLfile`

#### 1.2.2.2. Configurating GumTree to surpport HDLs

The support for HDLs can be configured with reference to GumTree's support for Python. The configurated files are placed in `gumtree-3.0.0-SNAPSHOT`.

### 1.2.3. Execution

#### 1.2.3.1 Collecting HDL projects from GitHub to create the subjects:

****Repositories in HDLs****

* Verilog: [e200_opensource](https://github.com/SI-RISCV/e200_opensource.git), [picorv32](https://github.com/cliffordwolf/picorv32.git), [wujian100](https://github.com/T-head-Semi/wujian100_open.git), [darkriscv](https://github.com/darklife/darkriscv.git), [hw](https://github.com/nvdla/hw.git), [amiga2000-gfxcard](https://github.com/mntmn/amiga2000-gfxcard.git), [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet.git), [hdl](https://github.com/analogdevicesinc/hdl.git), [zipcpu](https://github.com/ZipCPU/zipcpu.git), [miaow](https://github.com/VerticalResearchGroup/miaow.git)
* VHDL: [ghdl](https://github.com/ghdl/ghdl.git), [aws-fpga](https://github.com/aws/aws-fpga.git), [Open-Source-FPGA-Bitcoin-Miner](https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner.git), [FPGA_Webserver](https://github.com/hamsternz/FPGA_Webserver.git), [chipwhisperer](https://github.com/newaetech/chipwhisperer.git), [neorv32](https://github.com/stnolting/neorv32.git), [gplgpu](https://github.com/asicguy/gplgpu.git), [vunit](https://github.com/VUnit/vunit.git), [gcvideo](https://github.com/ikorb/gcvideo.git), [awesome-model-quantization](https://github.com/htqin/awesome-model-quantization.git)
* SystemVerilog: [opentitan](https://github.com/lowRISC/opentitan.git), [swerv_eh1](https://github.com/westerndigitalcorporation/swerv_eh1.git), [MinecraftHDL](https://github.com/itsFrank/MinecraftHDL.git), [rsd](https://github.com/rsd-devel/rsd.git), [hdmi](https://github.com/hdl-util/hdmi.git), [ibex](https://github.com/lowRISC/ibex.git), [lowrisc-chip](https://github.com/lowRISC/lowrisc-chip.git), [cv32e40p](https://github.com/openhwgroup/cv32e40p.git), [Cores-SweRV](https://github.com/chipsalliance/Cores-SweRV.git), [nontrivial-mips](https://github.com/trivialmips/nontrivial-mips.git)

****commads****

* `./collect_subjects.sh` After runing it, for Verilog, VHDL and SystemVerilog, there are ten repositories cloned into `subjects`, `subjects2`, `subject3` respectively.

#### 1.2.3.2. Collecting patch-related commits, parsing code changes of patches and measuring commit redundancy

* `./run.sh`

- If it executes successfully
  - The **first step** makes statistics of project LOC, which show the code line numbers of all projects respectively.
  - The **second step** collects bug-fix-related commits with bug-related keywords from project repositories.
It also will fileter out changes of test code. Its output consists of three kinds of files. The results in Verilog, VHDL, SystemVerilog are stored in `data`, `data2`, `data3` respectively.
      - **Buggy version** of a HDL code file containing a bug, stored in the directory "`<HDLdata>/PatchCommits/Keyword/<ProjectName>/prevFiles/`".
      - **Fixed version** of the Java code file, stored in the directory "`<HDLdata>/PatchCommits/Keyword/<ProjectName>/revFiles/`".
      - **Diff Hunk** of the code changes of fixing the bug, stored in the directory "`<HDLdata>/PatchCommits/Keyword/<ProjectName>/DiffEntries/`".
  - The **third step** will further filter out the HDL code files that only contain non-HDL code changes (e.g. comments).
  - The **fourth step** makes statistics of diff hunk sizes of code changes. The results will be stored in the directory "`<HDLdata>/DiffentrySizes/`".
  - The **fifth step** will parse code changes of patches and make statistics of fine-grained code entities impatced by patches. The results will be stored in the directory "`<HDLdata>/ParseResults/`". Meanwhile, the fix patterns are also collected and stored in the directory "`<HDLdata>/ParseResults/`".
  - The **sixth step** will perform a measurement of the redundancy of the patch-related commits. The results will stored in the directory "`<HDLdata>/ParseResults/`".

## 1.3. Scenarios to use HDLParser

### 1.3.1. For hardware developers

If correctly executed, HDLParser can provide detailed information (e.g. occurrence of buggy codes and corresponding repair actions) that hardware developers deepen their understanding on real bug fixes. The knowledge can help developers repair program effectively.

### 1.3.2. For researchers who want to explore APR towards HDLs

Based on the repair actions parsed from collected patches, HDLParser can provide the most frequent fix patterns that facilitate the design of pattern-based APR towards HDLs. 

HDLParser validates the redundancy assumption of bug fixing commits in HDLs that is fundamental assumption of various APR techniques. The redundancy assumption provides a smaller search space for donor codes.

These two areas of knowledge can support the development of APR in HDLs.

----

We will consistently develop and maintain this project to make it a better tool for the community. Also, all contributions are welcome.