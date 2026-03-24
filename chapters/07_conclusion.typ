#import "../dependencies.typ": *

= Conclusion <chapter_conclusion>

The embedded systems landscape is diversifying with the emergence of RISC-V as an open alternative to established ARM architectures. The Raspberry Pi RP2350 microcontroller offers both ARM Cortex-M33 and Hazard3 RISC-V cores in a single device, allowing developers to choose between architectures without changing hardware. However, operating system support for such heterogeneous platforms requires careful abstraction to maintain portability across different processor architectures.

The contribution of this thesis comprises several parts. First, a unified abstraction layer was implemented through the `rp2350_common` module, allowing applications to compile for either ARM or RISC-V without modifications. The abstraction uses compile-time flags and inline wrappers to handle architecture-specific differences transparently.

Second, support for the Hazard3 XH3IRQ custom interrupt controller was integrated into the `riscv_common` module through the `periph_xh3irq` feature. This enables future Hazard3-based devices to reuse the implementation. The integration maintains compatibility with existing interrupt handling patterns of RIOT while abstracting interrupt controller specifics between both architectures.

Third, multicore support was implemented using a worker-core model, in which the secondary core executes tasks independently of the main RIOT scheduler. Additional contributions include picobin image format integration through modifications of common linker scripts, support for OpenOCD and Picotool flashing methods, configurable clock management, and support for the RP2350 #gls(long: true, "pio") subsystem.

The evaluation showed that both architectures achieve comparable binary sizes with similar code distributions. Rust integration demonstrates the benefits of integrating the RP2350 into RIOT, with a minimal increase in binary size for Rust applications.
Integration with the RIOT CI system ensures ongoing validation through comprehensive test suites for both architectures.

Some limitations were identified. The Hazard3 core has non-standard @pmp permission bit ordering (Errata `RP2350-E6`), preventing standard RISC-V @pmp implementations from functioning correctly. The worker-core multicore model requires explicit task management rather than transparent scheduling, severely limiting applicability for thread-intensive workloads, compared to other multicore operating systems.

The RP2350 port provides RIOT users with access to an affordable dual-architecture development platform. The port enables use of RIOT ecosystem of network stacks, cryptographic libraries, and third-party packages on both ARM and RISC-V without vendor lock-in. The unified abstraction layer establishes design patterns applicable to future heterogeneous platforms.