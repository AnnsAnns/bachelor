#import "../dependencies.typ": *

= Analysis and Design <chapter_analysis>

In this chapter we analyze potential design considerations and requirements for porting RIOT OS to the RP2350 @mcu.

This includes the bootup sequence, interrupt controller, clock system, and threading model. This gives us a good framework to then implement the necessary low-level support and ensure that RIOT OS can effectively utilize the capabilities of the RP2350.

== Bootup Sequence <bootup_sequence_analysis>

=== Bootrom <bootrom_analysis>

The RP2350 features a built-in bootrom that is executed on power-up @raspberrypi:2025:rp2350[Chapter~5.2.2]. This bootrom is stored directly at `0x0` in a 32 kB immutable memory region and flashed onto the device during manufacturing @raspberrypi:2025:rp2350[Chapter~4.1].

The bootrom has a wide range of responsibilities, from boot slot selection to rollback protection, intended for secure applications @raspberrypi:2025:rp2350[Chapter~5].
However, for the context of this thesis, the most relevant parts of the bootrom are:

- Image and partition definition using picobin blocks
- Bootloader
- Architecture switching
- Core 0 boot code
- Core 1 launch preparations

=== Flashing <flash_op>

This thesis focuses on two primary flashing methods for the RP2350: OpenOCD and Picotool. These cover the most common use cases for flashing RIOT OS onto the RP2350, either through a SWD debugger or through USB mass storage device mode, thus offering flexibility for different development setups.

The RIOT build system abstracts the flashing process through the `PROGRAMMER` variable, allowing users to select their preferred flashing method through the build system, making it easy to switch between different flashing methods without dealing with the underlying implementation details.

An @mcu must simply declare their supported programmers, and offer relevant config options, such as the OpenOCD target file.

==== OpenOCD / Debugprobe <openocd_implementation>

OpenOCD (Open On-Chip Debugger) is a popular open-source tool for debugging and programming embedded devices using JTAG/SWD interfaces, including acting as a remote target for GDB #footnote("OpenOCD official website (Accessed 03.11.2025): http://openocd.org/").

The RP2350 allows for flashing and debugging through a SWD interface. Raspberry Pi recommends using their Debugprobe
#footnote("Debugprobe product link (Accessed 30.10.2025): https://www.raspberrypi.com/products/debug-probe/")
or a secondary Raspberry Pi Pico 1/2 as a SWD debugger flashed with a debugprobe firmware
#footnote("The debugprobe firmware can be downloaded here (Accessed 28.10.2025): https://github.com/raspberrypi/debugprobe") @raspberrypi:2024:getting-started-pico[Appendix A].

OpenOCD support for the RP2350 is, as of October 2025, still not integrated into any mainline OpenOCD release, requiring a custom build with RP2350 support #footnote("The RP2350 OpenOCD fork can be found here (Accessed 23.10.2025): https://github.com/raspberrypi/openocd").
RIOT OS already has support for OpenOCD as a flashing method, thus, as long as the custom OpenOCD build is used, no additional changes are required to support OpenOCD flashing for the RP2350.

==== Picotool <picotool_implementation>

`picotool` is a custom command-line tool developed by Raspberry Pi for interacting with Raspberry Pi Pico series over USB #footnote("Picotool official repository (Accessed 30.10.2025): https://github.com/raspberrypi/picotool").
RIOT already had support for `elf2uf2`, a predecessor to `picotool`, used for converting ELF files to the UF2 format used by the RP2040. `Picotool` support is thus a natural extension of this existing functionality and can reuse a significant portion of the existing integration codebase within RIOT OS.

UF2 (USB Flashing Format) is a file format developed by Microsoft designed for flashing @mcu:pl over USB mass storage device mode. It allows users to simply drag and drop firmware files onto the device when it appears as a USB drive #footnote("UF2 repository (Accessed 28.10.2025): https://github.com/microsoft/uf2").

Upon selecting `picotool` as the `PROGRAMMER`, the RIOT build system will automatically clone and build `picotool`. It then converts the compiled binary into the UF2 format, verifies that the UF2 file is valid, and finally uses `picotool` to flash the UF2 file onto the RP2350 over USB.

=== Image and Partition Definition (Picobin) <image_partition_definition_analysis>

==== Background

For the bootrom to load an application from flash, it needs to understand the specifics of the image in question, given the heterogeneous nature of the RP2350.
To allow such specifications the bootrom uses picobin blocks @raspberrypi:2025:rp2350[Chapter~5.1.4].

#figure(
    placement: auto,
    table(
        columns: (auto, 1fr),
        align: (left, left),
        [*Field*], [*Description*],
        [Block Start Marker], [Marks the beginning of a picobin block (Magic Value)],
        [Item Type], [Type of items in the block (e.g. Image Definition)],
        [Item Size], [Block size in words],
        [Image Type Flags], [
            - Bit 0-3: Image Type (e.g. Executable, Data) \
            - Bit 4-5: Security (e.g. Secure, Non-Secure) \
              Bit 6-7: Reserved \
            - Bit 8-10: CPU Architecture (e.g. RISC-V, ARM) \
              Bit 11: Reserved \
            - Bit 12-14: Chip (e.g. RP2350, RP2040) \
            - Bit 15: Try Before You Buy (TBYB) Image
        ],
        [Last Item Marker], [Marks the last item in the block],
        [Last Item Size], [Size of last item in words],
        [Next Block Pointer], [Relative pointer to next block (0 = self = no more blocks)],
        [Block End Marker], [Marks the end of the picobin block (Magic Value)],
    ),
    caption: [Picobin block structure for RP2350 image definition]
) <picobin_block_structure>

The block described in @picobin_block_structure should be placed within the first 4kB of flash memory. The bootrom will parse this block to determine which image to load based on the current architecture and security state of the core @raspberrypi:2025:rp2350[Chapter~5.1.5.1].

A single binary can have multiple picobin blocks to support different architectures and security states. The `Next Block Pointer` field indicates the relative position.

==== Design Considerations

Incorporating a picobin block into the RIOT OS build process involves a few key design considerations. First, the build system must be able to generate the picobin block with the correct fields based on the target architecture and security settings. This includes setting the appropriate `Image Type Flags` to indicate whether the image is for ARM or RISC-V and then link that binary blob into the final firmware image.

To achieve this, we must first look into how RIOT OS handles the build process and most notably how it manages linker scripts for different architectures.

The CPU defines a custom linker script under the `ldscripts` directory. In the case of the ARM version of the RP2350, this file would be `ldscripts/rp2350_arm.ld`. However, since both the ARM and RISC-V versions use an even higher abstraction layer through the `cortexm_common` and `riscv_common` module respectively, the actually important linker script is provided by these common modules, thus `ldscripts/rp2350_arm.ld` simply uses the `INCLUDE` directive to include the relevant common linker script.

This, however, poses a challenge as the aforementioned common linker scripts do not provide any hooks for adding custom sections, such as the picobin block. As such, there are two different approaches to solve this problem:
- Modify the common linker scripts to include hooks for custom sections.
- Create a new linker script specifically for the RP2350 that includes the picobin block.

Since these common modules are used by multiple @mcu:pl, modifying them could potentially introduce issues for other platforms. In the case of the `cortexm_common` module, the linker script is fairly lengthy and complex.


== Interrupt Controller

Interrupt handling on the RP2350 is complex due to the heterogeneous design. Each architecture has its own interrupt controller, with the ARM cores using a @NVIC and the Hazard3 cores using the XH3IRQ controller @raspberrypi:2025:rp2350[Chapter~3.8.4.2].

To facilitate cross-architecture compatibility, the RP2350 keeps the identical @irq:pl numbers for both, including support for platform-specific interrupts on both architectures @raspberrypi:2025:rp2350[Chapter~3.2].

The RISC-V Machine-mode timer interrupt `SIO_IRQ_MTIMECMP`, for instance, is a standard privileged interrupt for RISC-V @RV32I. However, both on the Hazard3 and Cortex-M33, the @irq is mapped to the value `29` and is functional @raspberrypi:2025:rp2350[Chapter~3.1.8].

In total, the RP2350 defines 52 @irq signals. The first 46 @irq signals are connected to peripheral interrupt sources, while the remaining 6 are intentionally hardwired to 0 for forceful self-interrupts via software @raspberrypi:2025:rp2350[Chapter~3.2].

=== #gls("NVIC", long: true)

@NVIC is a nested vectored interrupt controller designed by ARM for their Cortex-M series of processors. It provides a flexible and efficient way to manage interrupts, allowing for prioritization and preemption of @isr:pl. It also handles context saving and restoring during interrupt handling. The @NVIC design uses a vector table to map @irq numbers to their corresponding @isr addresses, in which the first entries are reserved for system exceptions, followed by device specific interrupts @nvic_YIU2014229.

On the Cortex-M33, the @NVIC allows up to 480 interrupts to be managed with a preemption level of 0 to 255, whereby a lower level signals a higher priority @st:2025:pm0264. As opposed to the custom XH3IRQ controller on the Hazard3 core, the @NVIC on the RP2350 Cortex-M33 follows the standard ARM design without any modifications.

=== XH3IRQ Controller <xh3irq_controller>

To minimize architectural differences, the Hazard3 core includes an interrupt controller extension called XH3IRQ. This extension adds a new set of Control and Status Registers (@CSR:pl) and instructions to the core that enable an interrupt handling mechanism similar to ARM @NVIC.

To facilitate this, the XH3IRQ controller adds 6 custom @CSR:pl, as described in @xh3irq_csrs.

#figure(
    table(
        columns: (auto, 1fr),
        align: (left, left),
        [*CSR*], [*Description*],
        [`meiea`], [Machine External Interrupt Enable Array (enables/disables interrupts)],
        [`meipa`], [Machine External Interrupt Pending Array (status of interrupts)],
        [`meifa`], [Machine External Interrupt Force Array (force interrupts)],
        [`meipra`], [Machine External Interrupt Priority Array (priority levels for interrupts)],
        [`meinext`], [Machine External Interrupt Next (pointer to next highest priority pending interrupt)],
        [`meicontext`], [Machine External Interrupt Context (Saves/informs about context during interrupt handling)],
    ),
    caption: [XH3IRQ custom @CSR:pl for interrupt management
@Hazard3Wren:datasheet[Chapter~4.1]]
) <xh3irq_csrs>

The XH3IRQ controller handles enabling, status, priority, and forced pending through a window system, as shown in @xh3irq_window_system.

#figure(
    table(
        columns: 3,
        align: (left, left, left),
        [*Bits*], [*Name*], [*Description*],
        [31:16], [window], [16-bit read/write window into the external interrupt array (1 bit per interrupt)],
        [15:5], [-], [Reserved],
        [4:0], [index], [Write-only, self-clearing field (no value is stored) used to control which window of the array appears in the window],
    ),
    caption: [XH3IRQ @CSR:pl register fields for Interrupt Pending Array (`meipa`), Interrupt Enable Array (`meiea`), Force Interrupt Array (`meifa`)]
) <xh3irq_window_system>

This window system, described in @xh3irq_window_system allows the XH3IRQ controller to manage 512 interrupts while only using a 32-bit @CSR. Thus, at 1 bit per interrupt, each window can manage 16 interrupts with 32 total windows @Hazard3Wren:datasheet[Chapter~3.8.1].

#figure(
    table(
        columns: 3,
        align: (left, left, left),
        [*Bits*], [*Name*], [*Description*],
        [31:16], [window], [16-bit read/write window into the external interrupt array (4 bits per interrupt)],
        [15:5], [-], [Reserved],
        [6:0], [index], [Write-only, self-clearing field (no value is stored) used to control which window of the array appears in window],
    ),
    caption: [XH3IRQ @CSR:pl register fields for the Interrupt Priority Array (`meipra`)]
) <xh3irq_priority_window_system>

To allow 16 preemption levels, the interrupt priority array @CSR uses a 7-bit index instead with a 4-bit value per interrupt, as described in @xh3irq_priority_window_system. Thus, each window can manage 4 interrupts with a total of 128 windows @Hazard3Wren:datasheet[Chapter~3.8.4].

The XH3IRQ controller supports two operational modes: direct and vectored. In direct mode, the interrupt handler address is fixed, and all interrupts jump to the same handler. In vectored mode, each interrupt can have its own handler address @Hazard3Wren:datasheet[Chapter~4.1].

The XH3IRQ controller also includes a context-saving mechanism that allows the current execution context to be saved and restored when handling interrupts. This is done using the `meicontext` @CSR and can optionally be enabled @Hazard3Wren:datasheet[Chapter~3.8.6].

Once the context is saved, the interrupt handler can be executed. After the handler is finished, the context can be restored and execution can continue from where it was interrupted through a `mret` call after completing the @isr @Hazard3Wren:datasheet[Chapter~3.2.9].

This is similar to the way ARM @NVIC handles context saving and restoring during interrupt handling, as both controllers automatically save the execution context when an interrupt occurs, allowing the processor to jump to the interrupt handler.
After the handler completes, the original context gets restored, and execution resumes from the point of interruption.
Additionally, both support preemption priorities, for which higher-priority interrupts can interrupt lower-priority ones, ensuring critical tasks are handled promptly.

=== Design Considerations

When designing the interrupt handling for the RP2350 port in RIOT OS, the goal is to create a unified abstraction layer that could handle interrupts for both architectures seamlessly. At the same time though, conforming to existing interrupt handling mechanisms of RIOT for both architectures.
Specifically, this means that we first needed to understand the existing interrupt handling mechanisms for both architectures in RIOT OS.

==== Cortex-M Interrupt Handling

The `cortexm_common` module in RIOT already includes support for the @NVIC, thus the design considerations for the RP2350 port were mostly about ensuring that the implementation we intend to provide for the Hazard3 XH3IRQ controller conforms to the existing design patterns used in the `cortexm_common` module, at least in a way that allows architecture-agnostic code to work seamlessly across both architectures.

In RIOT the @NVIC implementation uses a macro-based approach, in which the cpu module provides an extension to the interrupt vector table. Each vector that should be included in the final vector table gets a `.vector` label assigned using the `__attribute__((used,section(".vectors." # x )))` attribute. These attributes are then collected at the linking stage using a `KEEP(*(SORT(.vectors*)))` and sorted based on the assigned `x` value.

This way `cortex_common` ensures that common Cortex-M @irq handlers can be defined in a platform-agnostic way, while still allowing platform-specific handlers to be defined in the respective cpu module.

==== RISC-V Interrupt Handling

The interrupt handler of the `riscv_common` module functions in a fairly different way compared to the `cortexm_common` module.
The `riscv_common` module uses a single trap handler function that manages all interrupts and exceptions, opposed to the direct vector table jumps typical to @NVIC.
Depending on the enabled systems, such as @PLIC or @CLIC, the trap handler then passes the interrupt to the relevant sub-handler.

Given that the XH3IRQ controller needs a custom handling mechanism and the Cortex-M does not use a custom interrupt controller, the design consideration here was to implement the XH3IRQ handler in a way that fits into the existing trap handler mechanism of the `riscv_common` module while still allowing the RP2350 interrupt vector to be defined similarly to the vector table that the @NVIC uses for direct jumps.

==== Abstracting

#figure(
    placement: auto,
    image("../figures/ISR_Vector_THingy.drawio.pdf"),
    caption: [Diagram showing the design proposal for the route a hardware interrupt takes through the abstraction layers. Starting from the external trigger to the final user-defined @isr handler. Orange boxes are shared/common, blue boxes are ARM, green boxes are RISC-V.]
) <interrupt_external_trigger_abstraction>

Thus, the final design proposal for the interrupt handling abstraction uses an interrupt vector table similar to the one used by the @NVIC on the ARM side, while on the RISC-V side the trap handler function checks whether the interrupt originated from the XH3IRQ controller and then looks up the relevant handler in the vector table to call, as shown in @interrupt_external_trigger_abstraction.

While this does introduce some overhead that the XH3IRQ controller theoretically could avoid through direct vector jumps (See @xh3irq_controller), this design allows seamless integration into the existing interrupt handling mechanisms of RIOT for both architectures while still allowing architecture-agnostic code to define @isr handlers in a unified way.
The trap handler of the RISC-V implementation also goes beyond the scope of direct vector jumps the XH3IRQ controller handles, as it also deals with the scheduler, ecalls, faults and context switching.

Thus, the alternative of replacing the entire RISC-V interrupt handling mechanism within RIOT with a direct vector jump system for the RP2350 would have introduced significant complexity and maintenance burden of two competing interrupt handling mechanisms that would both need to be maintained in the future.

== Clocks <clock_analysis>

The RP2350 provides a flexible clocking system that allows for multiple clock sources and configurations. The main internal clock sources are the @ROSC, @XOSC, and @LPOSC @raspberrypi:2025:rp2350[Chapter~8.1.2].

These clock sources then get routed through a series of dividers to allow for a wide range of clock frequencies for internal components, such as the system clock used for processors and memory, the peripheral clock used by UART and SPI, or the reference clock used by the watchdog and timers @raspberrypi:2025:rp2350[Chapter~8.1].

=== #gls("ROSC", long: true) <rosc_analysis>

On startup, the @ROSC is used as the main clock source. Since hardware revision `RP2350 A3` the @ROSC operates at a randomized frequency on each power cycle to improve glitching attack resistance.
The intended nominal frequency provided to the reference clock by the @ROSC is 11 MHz, but due to the aforementioned randomization, it can vary largely.
Without randomization, the RP2350 guarantees a speed in-between 4.6 MHz and 19.6 MHz, depending on the operating voltage and temperature.

On revision `RP2350 A2` @ROSC is set to a randomized frequency between 4.6 MHz and 24.0 MHz. The `RP2350 A3` and later revisions quadruple the @ROSC frequency by reducing the divisor of the system clock to 2. This increases the standard range of the system clock to 18.4 MHz to 96.0 MHz.
Given that this is substantially higher than the nominal frequency of 11 MHz, `RP2350 A3` and later revisions increase the divisor of the reference clock to compensate @raspberrypi:2025:rp2350[Chapter~8.3.1].

Due to the volatility of the @ROSC frequency, it is not suitable for applications that require a stable clock source. Therefore, while not technically required, Raspberry Pi recommends to switch to the @XOSC after the initial boot sequence @raspberrypi:2025:rp2350[Chapter~8.3.4].

=== #gls("XOSC", long: true) <xosc_analysis>

The @XOSC on the RP2350 uses an external 12 MHz `ABM8-272-T3` ceramic SMD crystal to provide a stable clock source. This is the recommended clock source for most applications, especially those that require precise timing @raspberrypi:2025:rp2350[Chapter~8.2.1].
It should be noted that the RP2350 has a specified XOSC support range of 1 MHz to 50MHz if a different crystal is used @raspberrypi:2025:rp2350[Chapter~8.2.1].

To allow @XOSC to stabilize, it is advisable to wait for at least 1 ms after enabling it before switching the system clock to it. This can be done through a specialized startup delay timer set within the `CTRL_ENABLE` register
@raspberrypi:2025:rp2350[Chapter~8.2.3].

==== @XOSC Counter

The @XOSC COUNT register is relevant to this thesis as it allows for accurate hardware-based delays by counting the number of @XOSC cycles. Given the stable 12 MHz frequency of the @XOSC, this allows for precise timing without relying on software-based delays that can be affected by interrupts @raspberrypi:2025:rp2350[Table~603].

=== #gls("LPOSC", long: true)

To enable low power operation while the core is dormant, the RP2350 includes a low power oscillator (@LPOSC) running at a nominal 32.768 kHz.
Compared to the @XOSC, there is no configuration required to use the @LPOSC. When the system detects that the @XOSC is powered down for low power operations, it will automatically switch to the @LPOSC to keep the always-on logic running @raspberrypi:2025:rp2350[Chapter~8.4].

=== Design Considerations <clock_analysis_design>

When designing the clock system support for the RP2350 port in RIOT OS, the startup flow needed to be considered carefully. After evaluating all available clock sources, we decided to implement the clocks as shown in @clock_startup_sequence.

#figure(
    placement: auto,
    image("../figures/da_timer.drawio.pdf"),
    caption: [Proposed clock startup sequence for RP2350 port in RIOT OS. First, while running via @ROSC, the @XOSC is enabled. After a delay to allow it to stabilize, the system clock is switched to the @XOSC for stable operation.]
) <clock_startup_sequence>

IoT devices are often used in scenarios where battery and by that power consumption are a limiting factor. In works such as "Sense Your Power: The ECO Approach to Energy Awareness for IoT Devices" by Michel Rottleuthner @MichelSenseYourPower, it has been shown that energy awareness can significantly improve the battery life of IoT devices.
In the work, the authors propose an energy-aware design that allows the system to adapt its performance based on the current energy budget. This includes dynamically adjusting the clock speed to balance performance and power consumption.
While an implementation as presented in the work is out of scope for this thesis, allowing for the user to easily change the clock speed is relevant and important for the RP2350 port in RIOT OS and lays the groundwork for future energy-aware designs.

== Multi-Core Support <riot_threading_multicore_analysis>

=== Background

When RIOT was initially designed, it was built around the concept of a single core with a few MHz of processing power @Baccelli_RIOT_An_Open_2018[Chapter~2].

The RP2350 and most other modern @iot @mcu:pl however, significantly exceed these initial assumptions. Thus, in order to make use of these new capabilities, we first must understand how RIOT handles threading and scheduling in its current form and then adapt our approach accordingly.

RIOT uses a fixed-priority fixed-preemption scheduling model. Each thread is only interrupted through @irq:pl, otherwise, threads execute to completion @Baccelli_RIOT_An_Open_2018[Chapter~5b].
The main approaches to multi-core scheduling in the IoT OS field are global scheduling and partitioned scheduling. In global scheduling, one singular task queue is shared across all cores, and tasks are distributed onto available cores. In partitioned scheduling each core has its own task queue, and tasks are assigned to specific cores @Frank_2025[Chapter~2].

ArielOS adapts this scheduling model to a multi-core environment by implementing a global scheduler (a single scheduler managing threads across all cores) that can distribute tasks across both cores, as explained in @arielos_related_work.

While changing the scheduler of RIOT to a similar design as in @arielos_scheduler_architecture is theoretically possible, scheduler modifications were avoided in the design process.
Fitting such a critical code change into the scope of this thesis
exceeded the scope, given the complexity of multi-core scheduling and integrating it into the existing architecture of RIOT.

=== Design Proposal <riot_multicore_scheduling_analysis_design>

#figure(
    placement: auto,
    image("../figures/RIOTSCHEDULER.drawio.pdf"),
    caption: [Proposed "Worker Core" multi-core model for RIOT OS.
The main core (Core 0) offloads specific tasks to the secondary core (Core 1) which
runs them independently without any scheduler intervention.
    ]
) <riot_multicore_scheduling>

Thus, a method was required to start both cores and have them run independently without any scheduler intervention.
To achieve this, the secondary core is effectively isolated from the main RIOT OS environment as a worker core. It executes only what is directly assigned to it through inter-core communication mechanisms, as shown in @riot_multicore_scheduling.

Naturally, this design does come with drawbacks compared to @arielos_scheduler_architecture (See @arielos_related_work) would not have. The user is forced to design their application around this limitation, compared to a scheduler-based approach where the user can simply trust the scheduler to distribute tasks across both cores.

On the other hand, this design significantly reduces the complexity and maintenance burden of the implementation, as the entire multi-core logic can be contained within the RP2350 cpu module, which was the deciding factor for this design choice.

== #gls(long: true, "pio") <pio_analysis>

The official pico sdk uses a `pioasm` assembler tool to assemble @pio instructions. Since RIOT aims to be vendor neutral, integrating the `pioasm` tool directly into RIOT is not ideal. However, any user wanting to use the `pioasm` tool should still be able to do so easily.
The output format of the `pioasm` tool itself is however not compatible with RIOT as it also produces additional functions that rely on the Pico SDK. However, for our use case, we only require the raw assembled binary data to be loaded into the @pio memory.

Given the relatively small amount of instructions that can be stored in the @pio memory (32 instructions per state machine), it can be reasoned that programming PIO using C macros is feasible for most use cases. Thus, we propose a design where the user can define their @pio programs using C macros that directly encode the required instructions into binary data, as shown in @pioasm_integration. The developer would then simply manually execute the required setup at runtime to load the assembled binary into the @pio memory and launch the state machines @raspberrypi:2025:rp2350[Chapter~11.2.1].

#figure(
    placement: bottom,
    image("../figures/PIO.drawio.pdf"),
    caption: [Proposed design for integrating `pioasm` into the RIOT build system. The `pioasm` tool is built from the Pico SDK and then used to assemble @pio assembly files into raw binary data that can be included in the RIOT build process.]
) <pioasm_integration>

One notable design goal with this is that PIO should integrate into the existing RIOT GPIO driver abstractions so the user can easily switch between using standard GPIO pins and PIO-controlled pins without changing their application code significantly and reducing code duplication, thus increasing maintainability.
The @pio support we aim to provide is meant as a foundational layer for future more advanced PIO abstractions, such as a dedicated PIO driver that can manage state machines, load programs, and handle interrupts in a more user-friendly way.