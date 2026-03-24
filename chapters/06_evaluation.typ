#import "../dependencies.typ": *

= Evaluation <chapter_evaluation>

In this chapter, we evaluate the implementation of the RP2350 port in RIOT OS. We assess the practical performance characteristics of the port and verify if the design goals outlined in @chapter_analysis and @chapter_implementation have been achieved.

The evaluation starts with the multicore support implementation, where we measure the performance benefits of the "worker core" design discussed in @riot_threading_multicore_analysis. This is followed by a detailed code size comparison between the ARM Cortex-M33 and RISC-V Hazard3 architectures to validate the efficiency of the unified abstraction layer.

Finally, we demonstrate the ecosystem benefits of the RIOT integration, including the access to the comprehensive testing infrastructure and support for high-level languages.

== Multicore Support

=== Methodology

To evaluate the multicore support implemented in @chapter_implementation, we designed a series of tests to demonstrate the functionality and performance benefits of utilizing both cores, even in a more limited fashion as currently implemented.

As a simple demonstration of the functionality of both cores working in tandem, we implemented a dual-core GPIO test application @fig:core_gpio_impl. Both cores toggle separate GPIO pins as fast as possible. While this is a simple test, it effectively demonstrates that both cores can operate independently and concurrently in scenarios where, for example, vast amounts of data need to be transferred over GPIO.

As a point of comparison, we also implemented a single-core version, @fig:core_gpio_impl, of the same application, where only one core toggles both GPIO pins sequentially. The hypothesis is that the dual-core version should be twice as fast as the single-core version, assuming both cores can operate at full speed.
We run both tests on the Cortex-M33 core, measuring the toggling frequency of each GPIO pin using an oscilloscope.

#figure(
  placement: auto,
  grid(
    columns: 2,
    gutter: 0.2em,
      [```C
#define PIN_14 14u
#define PIN_15 15u

/* Single-core GPIO toggling both pins sequentially */
int main(void) {
    gpio_init(PIN_15, GPIO_OUT);
    gpio_init(PIN_14, GPIO_OUT);
    uint32_t selected_pin = PIN_15;
    while (1) {
        selected_pin = (selected_pin == PIN_15) ? PIN_14 : PIN_15;
        gpio_set(selected_pin);
        gpio_clear(selected_pin);
    }
    return 0;
}
  ```],
      [```C
/* This function runs on core 1 */
void* core1_main(void *arg) {
    (void)arg;
    gpio_init(PIN_14, GPIO_OUT);
    while (1) {
        gpio_set(PIN_14);
        gpio_clear(PIN_14);
    }
    return NULL;
}
/* This function runs on core 0 */
int main(void) {
    /* This will start core 1 and run core1_main on it */
    core1_init(core1_main, NULL);
    gpio_init(PIN_15, GPIO_OUT);
    while (1) {
        gpio_set(PIN_15);
        gpio_clear(PIN_15);
    }
    return 0;
}
  ```],
  ),
  caption: [Single-core GPIO toggling both pins sequentially (left) and dual-core GPIO toggling both pins in parallel (right).
  ]

) <fig:core_gpio_impl>

=== Results

We can observe the results of both tests using an oscilloscope in @fig:osc_comparison. The sequential toggling of both pins in the single-core version results in a lower frequency signal, as expected. In contrast, the dual-core version shows both pins toggling at a higher frequency and in parallel, confirming that both cores are functioning correctly and independently, given the simultaneous toggling of both GPIO pins.

#figure(
  placement: auto,
  grid(
    columns: 2,
    gutter: 0.2em,
    image("../figures/OSC_SINGLE.webp"),
    image("../figures/OSC_MULTI.webp")
  ),
  caption: [Oscilloscope captures showing single-core GPIO toggling (left) and dual-core GPIO toggling (right). Yellow (Top) is PIN 14, Blue (Bottom) is PIN 15.
    Single core average period: 560 ns, Dual core average period: 288 ns.
  ]
) <fig:osc_comparison>

The average signal period of each GPIO pin in the single-core test is approximately 560 nanoseconds.
In the dual-core test, the average signal period is around 288 nanoseconds.

In total, we can see a performance improvement of approximately 94.94% when utilizing both cores in parallel compared to a single core handling both tasks sequentially.

=== Discussion

Given the design choices explained in @riot_threading_multicore_analysis and the differences in approach to the multi-core scheduler of Ariel OS as discussed in @arielos_related_work, we can conclude that while the current implementation demonstrates the feasibility of multi-core processing on the RP2350 within RIOT OS, there is significant room for improvement.

Ariel OS and other operating systems that have been designed with multi-core support from the ground up, implement more sophisticated scheduling algorithms that can better utilize the capabilities of both cores. This includes load balancing, inter-core communication mechanisms, and more efficient context switching as discussed in "Multicore Scheduling and Synchronization on Low-Power Microcontrollers using Embedded Rust" by Elena Frank @frank:2024:multicore.

Comparing the results here with those of the master's thesis by Elena Frank, she achieves a performance improvement of 84% when utilizing both cores on the RP2040 in a CPU-bound workload. In the thesis, she calculated π using the Leibniz formula, sending calculation results between the cores, demonstrating that even a more advanced scheduler can achieve similar performance improvements in CPU-bound workloads while also utilizing more advanced features such as inter-core communication @frank:2024:multicore.

While inter-core communication is feasible with the current implementation using the methods described in @background_riot_os, we provide no higher level abstractions for it.
One of the key objectives stated in @chapter_objective of this thesis is the creation of a unified architecture abstraction layer that allows seamless switching between the ARM Cortex-M33 and Hazard3 RISC-V architectures within RIOT OS.

Both architectures can run RIOT OS with multi-core support, and the basic functionality of utilizing both cores has been demonstrated, which is something RIOT OS did not support before, which was a key objective of this thesis.
Yet the limitations of the current multi-core implementation, particularly in terms of scheduling and inter-core communication, indicate that there is still future work to be done when comparing to multi-core operating systems, such as Ariel OS.

== Code Size Comparison

To evaluate the efficiency of our implementation and compare the two architectures supported by the RP2350, we performed a detailed code size analysis of a minimal multicore application. This analysis provides insights into the memory footprint required for each architecture and helps identify optimization opportunities.

=== Methodology

We compiled a minimal dual-core GPIO application, @fig:core_gpio_impl, for both the ARM Cortex-M33 and RISC-V Hazard3 architectures. The application uses basic peripheral drivers (UART, GPIO) and demonstrates multicore functionality, making it representative of a typical embedded application on the RP2350.

RIOT provides a memory usage analysis tool called `cosy`, which we used to extract detailed size information from the compiled binaries #footnote[RIOT Cosy Repository (Accessed 04.01.2026): https://github.com/RIOT-OS/cosy/].
The measurements were performed with the standard RIOT build configurations for each architecture to ensure consistency. The builds were also done within the standard RIOT docker environment. RIOT ran in the default `-Os` optimization level, which enables all `-O2` optimizations except those that increase code size.
The chosen stack size here is the default size allocated by RIOT OS for each core depending on the architecture, which can be configured by the user.

=== Results

==== ARM Cortex-M33

The ARM build produces a binary with a total text section size of 7,610 bytes. @table:arm_code_size shows the breakdown by major components across all memory sections.

#figure(
  placement: auto,
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    [*Component*], [*Text (bytes)*], [*Data (bytes)*], [*BSS (bytes)*], [*Total (bytes)*],
    [cpu], [2576], [-], [2064], [4640],
    [core], [1972], [2], [1754], [3728],
    [pkg], [1768], [-], [-], [1768],
    [boards], [1012], [-], [-], [1012],
    [newlib], [96], [-], [-], [96],
    [sys], [86], [-], [-], [86],
    [app], [60], [-], [-], [60],
    [unspecified], [20], [-], [-], [20],
    [drivers], [16], [-], [-], [16],
    [fill], [4], [2], [2], [8],
    [*Total (Stacks)*], [*7610*], [*4*], [*3820*], [*11434*],
    [*Total (No Stacks)*], [*7610*], [*4*], [*236*], [*7850*],
  ),
  caption: [ARM memory section breakdown by component]
) <table:arm_code_size>

A noticeable contribution to the larger BSS section comes from the default stack allocation of 1536 bytes for each core and an additional 512 bytes for the isr_stack in RIOT OS on ARM Cortex-M33. Thus, a total of 3584 bytes are allocated for stacks by default.

@table:arm_cpu_breakdown shows the detailed breakdown of the `cpu` text section, revealing the contributions from the shared `rp2350_common` module, the `cortexm_common` module, and the ARM-specific `rp2350_arm` module.

#figure(
  placement: auto,
  grid(
    columns: 2,
    gutter: 1em,
    table(
      columns: (auto, auto),
      align: (left, right),
      [*Module/Symbol*], [*Size (bytes)*],
      [rp2350_common], [1394],
      [cortexm_common], [1168],
      [rp2350_arm], [14],
      table.hline(),
      [*Total*], [*2576*],
    ),
    table(
      columns: (auto, auto),
      align: (left, right),
      [*Module/Symbol*], [*Size (bytes)*],
      [periph], [784],
      [vectors.o], [224],
      [core.o], [164],
      [clock.o], [88],
      [xosc.o], [68],
      [cpu.o], [66],
      table.hline(),
      [*Total*], [*1394*],
    ),
  ),
  caption: [ARM cpu text section breakdown by module (left) and rp2350_common text section breakdown (right)]
) <table:arm_cpu_breakdown>

==== RISC-V Hazard3

The RISC-V build produces a slightly more compact binary with a total text section size of 7,587 bytes. @table:riscv_code_size shows the breakdown by major components.

#figure(
  placement: auto,
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    [*Component*], [*Text (bytes)*], [*Data (bytes)*], [*BSS (bytes)*], [*Total (bytes)*],
    [cpu], [2765], [208], [1300], [4273],
    [core], [2201], [-], [1754], [3955],
    [pkg], [2168], [-], [-], [2168],
    [sys], [156], [-], [-], [156],
    [newlib], [150], [-], [-], [150],
    [examples], [66], [-], [-], [66],
    [boards], [40], [-], [-], [40],
    [unspecified], [20], [-], [-], [20],
    [fill], [15], [-], [2], [17],
    [drivers], [6], [-], [-], [6],
    [*Total (Stacks)*], [*7587*], [*208*], [*3056*], [*10851*],
    [*Total (No Stacks)*], [*7587*], [*208*], [*240*], [*8035*],
  ),
  caption: [RISC-V memory section breakdown by component]
) <table:riscv_code_size>

On RISC-V, the default stack allocation is 1280 bytes for each core and 256 bytes for the idle stack, leading to a total of 2816 bytes allocated for stacks by default.
@table:riscv_cpu_breakdown shows the detailed breakdown of the `cpu` text section, revealing the contributions from `riscv_common`, the shared `rp2350_common` module, and the RISC-V-specific `rp2350_riscv` module. The larger data section can be explained by the XH3IRQ interrupt vector table we use to abstract the interrupt controller differences, which is stored in the data section (32-bit pointers for 52 interrupts = 208 bytes).

#figure(
  placement: auto,
  grid(
    columns: 2,
    gutter: 1em,
    table(
      columns: (auto, auto),
      align: (left, right),
      [*Module/Symbol*], [*Size (bytes)*],
      [riscv_common], [1441],
      [rp2350_common], [1308],
      [rp2350_riscv], [16],
      table.hline(),
      [*Total*], [*2765*],
    ),
    table(
      columns: (auto, auto),
      align: (left, right),
      [*Module/Symbol*], [*Size (bytes)*],
      [periph], [876],
      [core.o], [178],
      [clock.o], [94],
      [cpu.o], [78],
      [xosc.o], [64],
      [vectors.o], [18],
      table.hline(),
      [*Total*], [*1308*],
    ),
  ),
  caption: [RISC-V cpu text section breakdown by module (left) and rp2350_common text section breakdown (right)]
) <table:riscv_cpu_breakdown>

@table:riscv_cpu_breakdown provides a breakdown of the `cpu` module and the `rp2350_common` module for RISC-V, showing the individual object file contributions.

=== Analysis

The comparison reveals several important characteristics of both architectures:

*Text Section (Code Density):* Both architectures show remarkably similar text section sizes, with ARM at 7,610 bytes and RISC-V at 7,587 bytes, a difference of only 23 bytes (0.3%). This indicates that our unified abstraction layer effectively minimizes architecture-specific overhead, allowing both architectures to achieve comparable code density.

*Data Section:* The RISC-V build shows a notably larger data section (208 bytes vs 4 bytes on ARM). This difference stems from the RISC-V architecture storing the interrupt vector tables in the data section for interrupt controller compatibility purposes.

*BSS Section (RAM Usage):* When excluding stack allocations, both architectures show comparable BSS usage (236 bytes on ARM vs 240 bytes on RISC-V). The total BSS difference (3,820 bytes on ARM vs 3,056 bytes on RISC-V) is primarily due to differing default stack sizes. These stack sizes are configurable by the user based on application requirements, thus a direct comparison may not reflect actual application memory usage scenarios.

*Shared Components:* Both architectures benefit from the modular design of RIOT OS. The shared `rp2350_common` module contributes 1,394 bytes on ARM and 1,308 bytes on RISC-V, with the difference primarily in peripheral driver implementations and vector table handling. The `pkg` module shows sizes of 1,768 bytes on ARM vs 2,168 bytes on RISC-V, attributed to architecture-specific library optimizations.

*CPU Module:* The architecture-specific modules (`cortexm_common` at 1,168 bytes vs `riscv_common` at 1,441 bytes) reflect the differing interrupt handling and context switching mechanisms inherent to each architecture. Notably, the chip-specific modules (`rp2350_arm` at 14 bytes and `rp2350_riscv` at 16 bytes) are minimal, demonstrating the effectiveness of the unified abstraction layer.

*Total Memory Footprint:* The overall memory footprint is 11,434 bytes for ARM and 10,851 bytes for RISC-V (including stacks), or 7,850 bytes vs 8,035 bytes when excluding stack allocations. This represents a difference of less than 2.4% in either direction, confirming that the choice between architectures does not significantly impact memory requirements.

These results validate our implementation approach and demonstrate that both architectures provide viable options for RP2350 development. The choice between ARM and RISC-V can be made based on other factors such as toolchain preferences, debugging capabilities, or specific peripheral requirements, as the memory overhead differences are minimal. Even more so when considering the 520 kB of SRAM and 4 MB of onboard QSPI flash on the Rasperry Pi Pico 2.

=== Comparison with Pico SDK

To provide additional context, we compared the code size of our RIOT OS implementation with that of the official Raspberry Pi Pico SDK for the RP2350. For that, we implemented @fig:core_gpio_impl in the Pico SDK and compiled through their default build system. We followed the exact methodology outlined in the "Getting Started with Raspberry Pi Pico" guide, including compiling using the Microsoft Visual Studio Code Pico extension @raspberrypi:2024:getting-started-pico. The default core stack size on Pico SDK is 2048 bytes.

#figure(
  placement: auto,
  table(
    columns: (auto, auto, auto),
    align: (left, right, right),
    [*Memory Section*], [*Pico SDK*], [*RIOT OS*],
    [Code (.text)], [24688 bytes], [7610 bytes],
    [Data (.data/.rodata)], [17838 bytes], [4 bytes],
    [Zero-initialized (.bss)], [2417 bytes], [3820 bytes],
    table.hline(),
    table.cell(colspan: 3, [*Overall Memory Usage*]),
    [*Total*], [*44943 bytes*], [*11434 bytes*],
    [*Total (No Core Stacks)*], [*40847 bytes*], [*8362 bytes*],
  ),
  caption: [Memory comparison between Pico SDK and RIOT OS for dual-core GPIO application on the ARM Cortex-M33 cores]
) <table:pico_riot_comparison>

@table:pico_riot_comparison shows the memory usage comparison between the Pico SDK and RIOT OS for the same dual-core GPIO application on the ARM Cortex-M33 core. We can see a significant difference in memory usage, with the Pico SDK requiring 40,847 bytes compared to 8,362 bytes in RIOT OS. This substantial difference can be attributed to the overhead included by the Pico SDK, which may not be necessary for all applications, including a few fairly massive newlib components used within the RP2350 initialization of the SDK and not required by the written application code.

This indicates that the RP2350 port in RIOT OS follows the design goal of RIOT to be a lightweight operating system suitable for resource-constrained embedded systems, while still providing essential features and abstractions for application development and offers a more efficient memory footprint compared to the vendor SDK.

== Benefits of RIOT on RP2350

The idea of integrating the RP2350 into RIOT OS was driven by the potential benefits that RIOT OS could offer to such a @mcu, including the vast ecosystem of supported libraries, protocols and unit/integration tests that RIOT OS provides.

RIOT allowed us to abstract away many critical low-level details that would require significant design and implementation efforts to implement from scratch, including threading, cryptography, scheduling and other core OS functionalities. Any user willing to use RIOT on the RP2350 can now leverage these well-tested components without needing to reimplement them.

Comparing it to the official vendor `picosdk` SDK mentioned in @chapter_related_work, RIOT OS provides a considerable advantage in terms of available features and libraries, making it a valuable option for developers looking to build applications on the RP2350, without the vendor-lock-in of using the own SDK by Raspberry Pi. Examples include network stacks such as CoAP through `unicoap`, graphic drivers through `lvgl` or even Web Assembly support through `wamr`.

=== Unit Tests / Integration Tests

Through the integration with RIOT, we can leverage the existing unit and integrations tests, through the entire process of porting RIOT OS to the RP2350. Each commit made to the port could be verified against the existing test suite, including tests against all examples and the core/sys modules of RIOT OS.

The Murdock CI Runner of RIOT enables this by building the entire suite on large server clusters, reducing the time it would take to run the tests locally and by that enabling rapid iteration during development #footnote("One example test suite run (11.10.2025) showing all tests passing on the RP2350 (Accessed 14.11.2025): https://ci.riot-os.org/details/01fef4c5e621454aa199aa339fec965b").

Most notably it builds both the ARM and RISC-V versions of each test, ensuring that both architectures are always tested in parallel.

=== Rust Integration

Through RIOT OS support for Rust and C++, we were able to easily integrate these languages into our RP2350 port. In the example of Rust, all that was required was to add the appropriate target specifications.
The existing RIOT build system then takes care of compiling and linking the Rust code into the final binary, allowing us to leverage existing Rust libraries and tools within our RP2350 applications.

The Rust integration of RIOT is compatible with all existing code written for the RP2350, including the initialization, peripheral drivers and interrupt handling.
Thus, while this support was trivial to add for the RP2350 port, it stands as an example of the benefits that RIOT OS provides. Comparing it to the official Pico SDK which does not support Rust, the user is able to easily switch between these languages without leaving their existing codebase behind.

Looking into the binary size of a simple "Hello World" application, written in both C and Rust, we can see that the Rust version is only slightly larger than the C version, as shown in @fig:rust_size_comparison.

#figure(
  placement: auto,
  grid(
    columns: 2,
    gutter: 0.2em,
    image("../figures/c_hello_world.png"),
    image("../figures/rust_hello_world_cosy.png")
  ),
  caption: [Binary size comparison of a "Hello World" application written in C (left) and Rust (right) for the RP2350 RISC-V Hazard3 cores running RIOT OS. C TEXT size: 7483 bytes, Rust TEXT size: 7819 bytes.
    The different colors represent different modules, such as the core, rp2350_common or pkg that contribute to the final binary size.
  ]
) <fig:rust_size_comparison>

Aside from the access to the language itself, the RIOT Rust integration also provides access to the existing embedded Rust ecosystem, including the `embassy` async framework that is also used by Ariel OS (see @arielos_related_work). This allows users to leverage the benefits of async programming on the RP2350 within RIOT OS, opening up new possibilities for application design and architecture.

It should be noted that currently the Rust integration of RIOT does not support the Cortex-M33 cores of the RP2350, due to limitations in the existing RIOT Rust support. However, this could be added in the future, given the existing support for ARM Cortex-M architectures in the Rust embedded ecosystem.

=== Accessing Third Party Libraries

Unless a third party library has board/cpu-specific code, it can be used on the RP2350 without any modifications. The user can simply specify any library with `USEPKG` or `USEMODULE` in their application Makefile, and the RIOT build system will take care of the rest.
This is a significant advantage over using vendor-specific SDKs, where the user would often need to manually port or adapt third-party libraries to work with the specific SDK and hardware.

A good example of this is the usage of modules such as `stdio_uart`. Without RIOT, the user would need to implement their own STDIO over UART functionality, or adapt an existing library to work with the RP2350 hardware.
With RIOT, the user can simply include the `stdio_uart` module in their application, and it will work out of the box on the RP2350.
Such functionality has proven to be very useful during the entire development process, allowing quick iterations over the code that matters, rather than spending time on boilerplate code to get basic functionality working.

This ease of integration with libraries significantly lowers the barrier to entry for developers looking to build applications on the RP2350, allowing them to focus on their application logic rather than low-level hardware details.

=== PMP Support

The RIOT implementation of @pmp support (see @pmp_background) based on the work of Bennet Blischke complies with the official PMP specifications @blischke:2023:riscv-pmp. In the testing of the @pmp implementation on the RP2350 Hazard3 cores, we observed that the @pmp does not function as expected. Specifically, the RP2350 only supports eight @pmp regions instead of the standard 16 or 64 regions the specification allows.

This limitation hinders the effective use of the existing @pmp implementation in RIOT OS, as it requires vendor specific adjustments to function correctly on the RP2350, though the core implementation remains compliant with the RISC-V PMP specification.

However, Errata `RP2350-E6` breaks the @pmp specification conformity. The standard ordering for @pmp permissions is X, W, R (execute, write, read). The Hazard3 incorrectly interprets the ordering as R, W, X (read, write, execute) @raspberrypi:2025:rp2350.
The Hazard3 core v1.1 revision fixed this issue in April 2024
#footnote[The commit fixing the issue (Github, Accessed 03.11.2025): https://github.com/Wren6991/Hazard3/commit/7d370292b00f5bab846a1702ee24cc41179d631e].

Raspberry Pi decided to not include this fix in newer RP2350 revisions, instead opting to keep the errata. Based on the errata description, it can be assumed that this was done to maintain compatibility with existing software, as it states that the issue was fixed through "Documentation". This means that the @pmp implementation in RIOT OS will not work correctly on any RP2350 device.