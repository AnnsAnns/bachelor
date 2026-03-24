// Glossary
// Use: @key or @key:pl to reference and #print-glossary to print it
// More documentation: https://typst.app/universe/package/glossarium/

#let glossary-entry-list = (
  (
    key: "RV32I",
    short: "RV32I",
    description: 
[The base integer instruction set for 32-bit RISC-V processors. It includes basic arithmetic, logical, control flow, and memory access instructions.
It is the foundation for all RISC-V implementations and can be extended with optional instruction set extensions for additional functionality.],
  ),
  (
    key: "CSR",
    short: "CSR",
    description:
  [
Control and Status Registers (CSRs) are special-purpose registers in RISC-V processors that control various aspects of the processor operation and provide status information. These are privileged registers, meaning they can only be accessed in certain privilege modes (e.g., Machine mode). CSRs are used for tasks such as configuring interrupts, managing memory protection, and controlling performance counters @riscv:2025:privileged. ],
  ),
  (
    key: "three-stage",
    short: "three-stage pipelined",
    description:
    [
A three-stage instruction pipeline that improves performance by overlapping instruction execution. The stages are:
  - *Fetch* – fetches instructions from memory and performs predecoding
  - *Execute* – decodes and executes instructions and handles control flow
  - *Memory* – completes memory operations and writes results back to registers.
    ]
  ),
  (
    key: "pma",
    short: "PMA",
    description:
[The Physical Memory Attributes (PMA) specification defines how different types of memory regions behave in terms of caching, buffering, and ordering.
It provides guidelines for memory access to ensure correct operation and performance optimization @riscv:2025:privileged.
]
  ),
  (
    key: "first-party",
    short: "first-party",
    description:
    [In the context of software packages, "first-party" refers to packages or components that are developed and maintained by the original creators or maintainers of the software platform itself. In contrast, "third-party" packages are developed by external contributors or organizations not directly affiliated with the original software platform.]
  ),
  (
    key: "pll",
    short: "PLL",
    description:
    [A Phase-Locked Loop (PLL) is an electronic circuit that generates a stable output clock signal by synchronizing with a reference clock signal. It is commonly used in @mcu:pl to provide higher frequency clocks derived from a lower frequency source, enabling precise timing and frequency control for various system components.]
  ),
  (
    key: "vco",
    short: "VCO",
    description:
    [A Voltage-Controlled Oscillator (VCO) is an electronic oscillator whose output frequency is controlled by an input voltage. In the context of PLLs, the VCO generates a clock signal that can be adjusted based on the feedback from the PLL to maintain synchronization with the reference clock.]
  )
)

