#import "../dependencies.typ": *

= Background <chapter_background>

== RISC-V

RISC-V is an open-standard @isa based on established principles of @risc @riscv:2019:userisa.

The @risc design philosophy aims to simplify the processor design by using a small set of simple and general instructions.
This allows for easier implementation, lower power consumption, and higher performance by moving complexity from the hardware to the software, such as compilers and assemblers that can optimize instruction usage.

RISC-V expands on this concept by being open and extensible, allowing anyone to design, manufacture, and sell RISC-V processors without any licensing agreements.
This has led to a wide range of adoptions, from small @mcu:pl to high-performance processors, including the Hazard3 open-source core used by the RP2350.

RISC-V is still a relatively new architecture compared to architectures such as ARM and x86.
However, it has gained significant traction in recent years, experiencing a 276.8% growth from 2022 to 2023 with market analysts such as the SHD Group forecasting continuing rapid growth over the next decades @shdgroup:2024:riscv.

== ARM-M

The ARM-M family comprises @risc processors designed by ARM Holdings plc. Unlike RISC-V, ARM is a proprietary architecture, requiring companies to license the technology from ARM Holdings plc when used in their products
#footnote("ARM licensing information can be found here (Accessed 30.10.2025): https://www.arm.com/products/licensing").

The ARM-M family is designed for low-power, cost-efficient processors, making it ideal for embedded systems and IoT devices.
It features a simplified instruction set, a limited number of registers, and other optimizations intended for embedded systems.

The ARM-M architecture also includes various security features, such as TrustZone technology, which allows for the creation of secure and non-secure execution environments, as has been explored for RIOT OS in "Integration and Evaluation of a Secure Firmware for Arm Cortex-M Devices in RIOT OS"@boeckmann:2025:secure-firmware.

While RISC-V is gaining traction in the embedded systems industry @shdgroup:2024:riscv,
ARM-M remains a dominant architecture for low-power embedded systems due to its maturity, extensive ecosystem, and wide range of available tools and libraries, including the Cortex-M series of processors, such the RP2350 Cortex-M33 core.

== RIOT OS <background_riot_os>

RIOT OS is an open-source @os for low-end embedded devices in the @iot. It is vendor-neutral and lightweight on as little as 3.2 kB of ROM and 2.8 kB of RAM under minimal configurations @Baccelli_RIOT_An_Open_2018.

The focus of RIOT on modularity and modifiability facilitates the easy integration of new features, including new @mcu:pl and @board:pl.
Accompanied by a comprehensive set of tutorials and documentation to help new users get started with the @os #footnote("RIOT OS documentation can be found here (Accessed 30.10.2025): https://guide.riot-os.org/").

RIOT also offers a vast number of packages that can be utilized by newly ported boards after the initial setup.
Currently, RIOT does not support heterogeneous architectures or multicore systems.

RIOT does, however, support both ARM and RISC-V architectures, including a comprehensive abstraction for architecture specific common code, which makes it a good candidate for the RP2350.

=== RIOT OS Support for New @mcu:pl

RIOT OS adopts a modular approach to peripheral and module support. Each peripheral or module is implemented as a separate driver that can be included or excluded depending on the target @board or @mcu @Baccelli_RIOT_An_Open_2018[Chapter~6].

The minimal support level RIOT OS requires of any added @mcu is a bootable system capable of running a basic application, preferably including threading, though under special circumstances, a single-threaded system is also acceptable @Baccelli_RIOT_An_Open_2018[Chapter~5].

From there, additional peripherals and most essential functionality can be added incrementally, such as interrupts, timers, GPIO, and UART.

=== RIOT Principles <riot_principles>

#figure(
  image("../figures/riot_modules_thingy.drawio.pdf"),
  caption: [RIOT OS modular architecture showcasing the kernel, drivers, and applications. Going from highly hardware-dependent modules to hardware-agnostic ones.]
) <riot_modularity>

RIOT separates hardware-dependent code from hardware-agnostic code through a layered architecture where each layer only interacts with the layer directly above or below it, rarely crossing layers as seen in @riot_modularity.

In essence, hardware-dependent code is limited to the @mcu `cpu` drivers and `boards` board.
The @mcu driver, depending on the @mcu and board, provides access to peripherals `periph` such as GPIO, timers, UART, SPI, and I²C.
The board file then maps these peripherals to physical pins and configures any board-specific settings, such as UART baud rate or LED active high/low.

These components use a common peripheral API `drivers` / `periph` defined by RIOT OS.
This API enables hardware-agnostic code, such as network stacks, file systems, and applications, to use these peripherals without knowledge of the underlying hardware @Baccelli_RIOT_An_Open_2018[Chapter~6c].

Another useful side effect of this modularity is that swapping out hardware becomes easier.
Provided the new hardware has a RIOT OS @mcu driver and a board file, the remainder of the system usually remains unchanged.

RIOT also offers third-party packages through the `pkg` directory.
These packages can be added to a RIOT OS project through a simple `USEPKG` directive in the `Makefile`, enabling the integration of new functionality without the need to modify the core RIOT OS codebase.
Examples include libraries, such as `lvgl` for graphical user interfaces, `micropython` for Python scripting support, or `tinyusb` for USB support
#footnote("A comprehensive list of available packages can be found here (Accessed 30.10.2025): https://github.com/RIOT-OS/RIOT/tree/master/pkg").

@First-party packages are also modular and can be included from the `sys` directory. This includes essential functionality such as networking, file system, and cryptography.

The `core` directory contains the RIOT OS kernel and essential services such as the scheduler, memory management, and inter-process communication.
This layer is hardware-agnostic and can run on every supported @mcu
#footnote("More information about the RIOT OS structure can be found here (Accessed 30.10.2025): https://guide.riot-os.org/general/structure/").

RIOT ensures that all the aforementioned layers are well tested through a comprehensive suite of unit and integration tests. This testing helps to maintain the stability and reliability of the system as new features and @mcu support are added, and existing components are modified #footnote("CI can be accessed here (Accessed 29.10.2025): https://ci.riot-os.org/details/branch/master").

== RP2350

=== RP2350 Overview

The RP2350 is a low-cost @mcu developed by Raspberry Pi. The Raspberry Pi Pico 2 serves as the reference @board for the RP2350. Throughout this thesis, the terms _RP2350_ and _Raspberry Pi Pico 2_ are used interchangeably.

The RP2350 features both a dual-core ARM Cortex-M33 and a dual-core Hazard3 RISC-V processor, which can be switched between while retaining full access to peripherals and memory.
Both processors run at 150MHz on the Pico 2 @board @raspberrypi:2025:rp2350[Chapter~1].
The Pico 2 @board includes 520 kB of SRAM, 4 MB of onboard QSPI flash, two UARTs, two SPI controllers, two I2C controllers, 24 PWM channels, 26 GPIO pins, and three @pio subsystem blocks, each supporting four state machines @raspberrypi:2024:pico2.

The RP2350 is the first heterogeneous architecture developed by Raspberry Pi @raspberrypi:2024:pico2:announcement.
It succeeds the RP2040, which includes dual ARM Cortex-M0+ cores, 264kB of SRAM, and the first version of @pio @raspberrypi:2020:rp2040. RIOT OS already includes support for the RP2040, however, the RP2350 drastically changes the architecture by introducing RISC-V cores and a more advanced Cortex-M33 core, thus requiring a new port.

The RP2350 is designed for low-power applications and is suitable for use in a wide range of embedded systems, including IoT devices, wearables, and home automation systems.
At the time of writing, three public revisions of the RP2350 exist: `RP2350 A2`, `RP2350 A3`, and `RP2350 A4`, released in July 2025.
These mostly contain bug fixes and security improvements @raspberrypi:2025:rp2350[Appendix C]. This thesis is based on revision `RP2350 A3` of the RP2350, as revision `A4` was released after the initial research phase.

=== Hazard3

#figure(
  placement: auto,
  table(
    columns: 2,
    align: (left, left),
    table.header([*Extension*], [*Description*]),
    [@RV32I v2.1], [Base integer instruction set with 32-bit registers @riscv:2019:userisa ],
    [M v2.0], [Integer multiplication and division instructions @riscv:2019:userisa],
    [A v2.1], [Atomic memory operations @riscv:2019:userisa],
    [C v2.0], [Compressed 16-bit instructions for reduced code size @riscv:2019:userisa],
    [Zicsr v2.0], [@CSR read/write instructions @riscv:2019:userisa],
    [Zifencei v2.0], [Instruction-fetch fence for self-modifying code @riscv:2019:userisa],
    [Zba v1.0.0], [Address generation bit manipulation instructions @riscv:2021:bitmanip],
    [Zbb v1.0.0], [Basic bit manipulation instructions @riscv:2021:bitmanip],
    [Zbc v1.0.0], [Carry-less multiplication instructions @riscv:2021:bitmanip],
    [Zbs v1.0.0], [Single-bit manipulation instructions @riscv:2021:bitmanip],
    [Zbkb v1.0.1], [Bit manipulation for cryptography @riscv:2023:crypto],
    [Zcb v1.0.3-1], [Code size reduction with additional compressed instructions @riscv:2024:codesize],
    [Zcmp v1.0.3-1], [Push/pop and double move compressed instructions @riscv:2024:codesize],
    [Machine ISA v1.12], [Machine-mode privileged instructions @riscv:2025:privileged],
    [Debug v0.13.2], [External debug support @riscv:2024:debug],
    [Xh3bextm], [Custom bit extraction multiple instructions (`h3.bextm`, `h3.bextmi`)],
    [Xh3irq], [Custom interrupt controller],
    [Xh3pmpm], [Custom @CSR:pl for M-mode @pmp enforcement],
    [Xh3power], [Custom power management with `msleep` @CSR and hint instructions],
  ),
  caption: [RISC-V extensions supported by Hazard3]
) <hazard3_extensions>


Hazard3 is a @three-stage RISC-V processor used by Raspberry Pi in the RP2350 @mcu. It was designed by Luke Wren and is open-source @Hazard3Wren. The Hazard3 includes various extensions that introduce new @CSR:pl and instructions, as listed in @hazard3_extensions.

Although the Hazard3 is designed with modularity in mind, this thesis assumes that all of the above extensions are present, given that they are all implemented by the RP2350 @raspberrypi:2025:rp2350[Chapter~3.8].

==== #gls("pmp", long: true) <pmp_background>

Physical Memory Protection (@pmp) is a security feature of RISC-V that allows the definition of memory regions with specific access permissions @riscv:2025:privileged[Chapter~3.7].

Although the Hazard3 supports 16 @pmp regions @Hazard3Wren:datasheet[Chapter~3.3], the RP2350 implementation is configured for only eight @pmp regions at 32-byte granularity, followed by three hard-wired regions @raspberrypi:2025:rp2350[Chapter~10.4].

The RIOT implementation of @pmp follows the ISA specification, where only 16 or 64 regions are supported @blischke:2023:riscv-pmp[Chapter~2.2.4].

=== Cortex-M33 <cortex_m33>

The Cortex-M33 is the first @three-stage Armv8-M based processor and stands as one of the more powerful ARM @mcu:pl @arm_overview_ieee.

The RP2350 supports both Secure and Non-Secure states through the ARM TrustZone technology @raspberrypi:2025:rp2350[Chapter~3.7.2].
This thesis focuses on the Non-Secure state of the Cortex-M33, as RIOT does not have a merged integration of this technology @boeckmann:2025:secure-firmware, and the Hazard3 exclusively supports Non-Secure mode. Thus, the Non-Secure mode is the only common denominator between the two architectures.

=== #gls("pio", long: true)

#gls("pio", long: true) is a distinctive feature of the Raspberry Pi Pico @mcu family.
It was first introduced in the RP2040 and has been updated in the RP2350 @raspberrypi:2025:rp2350[Chapter~11.1.1].

#figure(
  placement: auto,
  image("/figures/PIO_STATE_MACHINE.drawio.pdf"),
  caption: [Overview of a @pio state machine. Showcasing the shared instruction memory, access to the FIFO buffer, and interrupts. ]
) <pio_state_machine>

The RP2350 contains three identical @pio blocks.
Each block includes four state machines programmable in a custom assembly language.
The state machines can operate independently or in parallel, allowing complex I/O operations to be offloaded from the main processors.

In total, the PIO assembly language has nine instructions, as explained in @pio_instructions, that, when combined, allow for fairly complex operations, such as generating precise waveforms, handling serial protocols, or bit-banging custom interfaces. @raspberrypi:2025:rp2350[Chapter~11.4].

#figure(
  placement: auto,
  table(
    columns: 2,
    align: (left, left),
    table.header([*Instruction*], [*Description*]),
    [`JMP`], [Jump to address if condition is true],
    [`WAIT`], [Stall until condition is met (GPIO/pin/IRQ/jmppin)],
    [`IN`], [Shift data from source into Input Shift Register],
    [`OUT`], [Shift data from Output Shift Register to destination],
    [`PUSH`], [Push ISR contents to RX FIFO],
    [`PULL`], [Pull data from TX FIFO into OSR],
    [`MOV`], [Move data between registers],
    [`IRQ`], [Set or clear IRQ flags],
    [`SET`], [Set pins or register to immediate value],
  ),
  caption: [@pio assembly instructions]
) <pio_instructions>

Each state machine (@pio_state_machine) can read and write to a FIFO buffer, which can be used to communicate with the main processors.
In total, each state machine has eight 32-bit buses, by default configured as four inputs and four outputs.
This design allows for flexible communication between the state machines and the main processors.

For high bandwidth operations, the RP2350 supports eight unidirectional 32-bit buses, allowing for eight input or eight output buses exclusively @raspberrypi:2025:rp2350[Chapter~11.5.3].

Each state machine can also trigger and respond to interrupts.
In total, there are eight IRQ flags shared among all state machines.
State machines can both trigger and wait for these IRQ flags @raspberrypi:2025:rp2350[Chapter~11.4.11].

In total, each state machine has four registers:
- The `X` and `Y` registers are general-purpose registers that can be used for arithmetic and logic operations.
- The @ISR_reg and @OSR are used for serial data input and output operations.

The instruction memory is shared between all state machines in a block. Holding a total of 32 instructions per block.

@pio runs on the system clock. This would, however, be too fast for most I/O operations. To mitigate this, each state machine has a configurable clock divider that can be used to slow down the execution of instructions.

The clock divider modifies the number of clock cycles that count as one execution cycle of the state machine, instead of reducing the clock frequency @raspberrypi:2025:rp2350[Chapter~11.5.5].

=== Inter-Processor Communication

The RP2350 features a few different mechanisms that enable synchronization and communication between its cores.

==== Spinlocks

The RP2350 includes 32 hardware spinlocks and an additional 32 software locks for Secure mode.
Each spinlock is a single flag bit that can be set or cleared by either core.
If a core tries to acquire a lock that is already held by the other core,
it will spin in a loop until the lock is released @raspberrypi:2025:rp2350[Chapter~3.1.4].

==== Atomic Memory Operations
The RP2350 supports atomic access to SRAM based on the Armv8-M Global Exclusive Monitor mechanism.
The implementation covers nearly all atomic RISC-V operations as defined in the atomicity @pma specification, except for the @lrsc `RsrvEventual` option @raspberrypi:2025:rp2350[Chapter~2.1.6].

#gls("lrsc", long: true) is a pair of instructions
used in RISC-V to implement read-modify-write operations. The LR instruction loads a value from memory and marks the address as "reserved". The SC instruction attempts to store a new value to the same address, but only if it is still marked as reserved (i.e., no other writes have occurred to that address since the LR). If the store is successful, it indicates that the operation was atomic; otherwise, it fails, and the operation must be retried @riscv:2019:userisa.

There are three support levels for @lrsc @pma reservability:
- `RsrvNone`: No @lrsc operations are supported (locations are not reservable)
- `RsrvNonEventual`: @lrsc operations are supported, but the reservation may be lost
- `RsrvEventual`: @lrsc operations are supported and guarantee eventual success

The RISC-V Privileged Architecture specification recommends support for `RsrvEventual` and states that `RsrvNonEventual` support should include fallback mechanisms when lack of progress is detected @riscv:2025:privileged[Chapter~3.6.3.2].

Raspberry Pi justifies not supporting `RsrvEventual` by noting that while artificial scenarios without progress guarantees can be theoretically constructed, practical implementations with properly bounded atomic sequences typically complete quickly without requiring additional fallback mechanisms @raspberrypi:2025:rp2350[Chapter~2.1.6].

==== Doorbell

The RP2350 features a core-local doorbell interrupt (identified as `SIO_IRQ_BELL` at IRQ 26) that can be triggered by either core or by itself. This mechanism enables event signaling between cores in scenarios where event ordering is not critical or where multiple events can be processed within a single interrupt handler @raspberrypi:2025:rp2350[Chapter~3.1.6].

==== Inter-Processor FIFOs <inter_processor_fifos>

The primary inter-processor communication mechanism consists of two hardware FIFOs, each 32 bits wide and four elements deep. Each FIFO is readable by one core and writable by the other. The FIFOs support interrupt generation when non-empty (for the reading core) or non-full (for the writing core) @raspberrypi:2025:rp2350[Chapter~3.1.5].

These FIFOs are utilized by both the RP2350 bootloader and the multicore startup procedure, as discussed further in @multicore_implementation