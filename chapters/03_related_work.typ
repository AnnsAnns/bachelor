#import "../dependencies.typ": *

= Related Work <chapter_related_work>

This chapter reviews existing work relevant to the implementation of RIOT OS support for the RP2350. It examines prior efforts in porting operating systems to embedded architectures, security analyzes of the RP2350 platform, and alternative operating systems and frameworks that support the RP2350. These works provide context for the design decisions and implementation approaches taken in this thesis.

== Inferno OS on ARMv7-M

A relevant contribution in this field is the masters thesis "Porting Inferno OS to ARMv7-M and Cortex-M7" by Petter Duus Berven @berven:2022:inferno. In that work, the author ported the Inferno operating system, a distributed non-real-time OS derived from Plan 9, to the ARMv7-M architecture used in Cortex-M @mcu:pl.

Plan 9 is an operating system developed at Bell Labs in 1992, designed with a focus on distributed computing and simplicity @pike1990plan.
In Plan 9 only the most core and essential components are part of the kernel #footnote([Called 'devices' in Plan 9 @pike1990plan.]), while most other functionality is run outside the kernel #footnote([Called 'servers' in Plan 9 @pike1990plan.]).
Inferno OS, similar to RIOT OS, allows a fairly modular design, with a small kernel.

The thesis focused on extending the custom compiler toolchain of Inferno to generate ARM Thumb instructions, implementing low-level hardware support for the Teensy 4.1 board, and adapting core kernel components.
In his thesis, Berven highlights common challenges including incomplete compiler backends, limited instruction-set coverage, and the need to redesign low-level exception handling, memory layout, and startup code.

While Berven's project targeted a homogeneous ARM-based environment, this work is relevant to the current thesis as it provides insights into the complexities of porting an operating system to a different architecture, which can inform the approach taken for porting RIOT OS to the RP2350.

== Security through Transparency: Tales from the RP2350 Hacking Challenge

In "Security through Transparency: Tales from the RP2350 Hacking Challenge" @muench2025security, the authors discuss the security aspects of the RP2350 architecture that were found in the process of a hacking challenge organized by Raspberry Pi Ltd.
They analyze various vulnerabilities and attack vectors, providing insights into the security challenges associated with heterogeneous architectures. In it, the authors discuss attacks on the @otp @psm, vector boot and signature verification to bypass secure boot.

While the main focus of the paper is on exploring the security of the RP2350 and methods to defeat it, the paper provides a comprehensive overview of the underlying hardware and boot sequence of the RP2350, which aids in understanding the low-level initialization of the RP2350 when implementing RIOT OS support.

Although this thesis does not focus on security aspects, as discussed in @cortex_m33, RIOT OS TrustZone support is out of scope and not yet merged into mainline RIOT OS, understanding the security features of the RP2350 remains important for future work building upon this thesis.

== Evaluation of RISC-V Physical Memory Protection in Constrained IoT Devices

In "Evaluation of RISC-V Physical Memory Protection in Constrained IoT Devices" @blischke:2023:riscv-pmp, Bennet Blischke explores the use of the RISC-V Physical Memory Protection (PMP) unit in the context of constrained IoT devices running RIOT OS.
In his thesis, Blischke implements data execution prevention and thread stack overflow detection using the RISC-V PMP, evaluating its effectiveness and performance impact.

While this does not directly relate to the RP2350 porting effort, his work serves as a foundation for demonstrating the benefits of enabling RIOT OS support on the RP2350 platform, as it allows leveraging the RISC-V PMP features on the Hazard3 core with minimal additional effort.

One of the conclusion of this work is that most existing PMP implementations do not properly comply with the specifications, we will extend the findings of this work in @chapter_evaluation when evaluating the PMP implementation of the Hazard3 core in the RP2350.

== ArielOS <arielos_related_work>

In "Ariel OS #footnote("ArielOS can be found here (Accessed 28.10.2025): https://github.com/ariel-os/ariel-os"): An Embedded Rust Operating System for Networked Sensors & Multi-Core Microcontrollers," the authors present ArielOS a new operating system for embedded devices, written in Rust. It aims to provide a safe and secure environment for IoT applications, including support for multicore @mcu:pl @Frank_2025.
While still retaining much of the design philosophy of RIOT OS, ArielOS focus on multicore systems differentiates it from RIOT OS.

// as RIOT OS has focused on single-core systems, given the historic prevalence of such systems in the embedded space.

ArielOS includes support for the RP2350 from the beginning, making it an interesting point of comparison for this thesis. It was designed with the RP2350 and similar systems in mind @Frank_2025[Chapter~1].
RIOT OS, on the other hand, was designed at a time when single-core 8 bit and 16 bit @mcu:pl were fairly common in the embedded space @Baccelli_RIOT_An_Open_2018[Section~2], which is something that ArielOS does not target or support.

Under the hood, ArielOS differs significantly from RIOT OS. It leverages the pre-existing Rust ecosystem for embedded systems, using libraries such as Embassy as building blocks for the operating system @Frank_2025[Chapter~5].
This is in contrast to RIOT OS, which implements most of its functionality from scratch in C.

Embassy is an asynchronous runtime for embedded systems in Rust, providing abstractions for concurrency and hardware access #footnote("Embassy can be found here (Accessed 28.10.2025): https://github.com/embassy-rs/embassy").
In the case of the RP2350, ArielOS uses Embassy for the underlying hardware access, binding the implementation offered by the `embassy_rp` crate to its own abstractions #footnote("embassy_rp can be found here (Accessed 30.10.2025): https://github.com/embassy-rs/embassy/tree/main/embassy-rp/").

Referring to @riot_modularity as explained in @riot_principles, this means that compared to RIOT OS, ArielOS still offers abstraction layers, but the underlying implementation of `cpu`, `drivers`, and peripherals is provided by Embassy rather than being originated from the OS #footnote("The implementation of the RP2350 in ArielOS can be found here (Accessed 30.10.2025): https://github.com/ariel-os/ariel-os/tree/main/src/ariel-os-rp").
ArielOS then provides core system services such as multicore task scheduling, inter-process communication, and memory management on top of Embassy, similar to how RIOT OS builds its core services on top of its own hardware abstractions.

The scheduler in ArielOS is designed as a continuation of the tickless real-time scheduler of RIOT OS with preemptive priority scheduling, extended to support multicore systems. The exploration of multicore scheduling is further expanded in the original master's thesis "Multicore Scheduling and Synchronization on Low-Power Microcontrollers using Embedded Rust" by Elena Frank in which she explores the design and implementation of a multicore scheduler for `RIOT-rs`, which later evolved into ArielOS @frank:2024:multicore.

#figure(
  placement: auto,
  image("../figures/ARIELOSSCHEDULER.drawio.pdf"),
  caption: [
ArielOS Scheduler Architecture.
After startup, Core 0 initializes the system and starts Core 1 via the FIFO (See @inter_processor_fifos).
Then, both cores run the same scheduler, triggered through FIFO messages from either core to handle task scheduling.
  ]
) <arielos_scheduler_architecture>

ArielOS utilizes a global scheduling approach, as shown in @arielos_scheduler_architecture, where tasks are not bound to a specific core (though they can have a core affinity if desired), together with a shared mutually-exclusive kernel design @Frank_2025[Chapter~5D].
The authors argue that such a global scheduling approach is acceptable on @iot @mcu:pl given the low number of cores and limited parallelism @Frank_2025[Chapter~5B].

On the RP2350, it uses the same process to start both cores as described in @multicore_implementation. After the startup process, it uses the FIFO to pass scheduler invocations between the two cores @Frank_2025[Chapter~6B]. Specifically, when the scheduler needs to be invoked in a multicore system, ArielOS uses a global spinlock through the RP2350 FIFO to synchronize a global critical section for all cores @Frank_2025[Chapter~5F].

ArielOS represents a different approach to supporting the RP2350 compared to the work done in this thesis as it modifies the concept of the RIOT OS scheduler to support multicore systems directly, rather than building around the existing RIOT OS scheduler design, which is inherently single-core.
Nonetheless, given its similarity to the RIOT OS scheduler, ArielOS provides a valuable comparison for the multicore design decisions made in this thesis and how they can be improved in future work.
ArielOS also demonstrates that supporting the RP2350 in an embedded operating system is feasible and can provide a solid foundation for further exploration of heterogeneous architectures in embedded systems.

== Pico SDK

Pico SDK is the official software development kit for the Raspberry Pi Pico #footnote("PicoSDK can be found here (Accessed 28.10.2025): https://github.com/raspberrypi/pico-sdk").
Compared to RIOT OS or other operating systems, the Pico SDK is designed solely for the Pico series, similar to other vendor SDKs such as esp-idf from Espressif #footnote("esp-idf can be found here (Accessed 28.10.2025): https://github.com/espressif/esp-idf").

The SDK aims to be a development framework rather than a full operating system, providing low-level access to the hardware and basic libraries for common tasks, but not including the benefits that come with a full operating system.

Given that this is a vendor SDK, it offers the widest support for RP2350 hardware features. It uses a CMake build system for building applications. The user must manually specify which modules to include in their application, similar to how RIOT OS allows users to select modules at compile time.

=== Abstraction

One of the core themes of this thesis is the abstraction of architectural differences between the ARM and RISC-V cores in the RP2350. The Pico SDK uses compile-time flags to differentiate between the two architectures.

It also shares a common abstraction layer between the RP2040 and RP2350, mostly sharing headers and higher-level libraries. The RP2040 was the predecessor of the RP2350, sharing most peripherals, though having a different purely ARM Cortex-M0+ dual-core architecture. While not supporting all peripherals, RIOT OS does also offer support for the RP2040.

While this approach works well for a vendor SDK, it lacks the modularity and flexibility of RIOT OS. The Pico SDK approach is hardware-dependent by design, making it less suitable for applications that require portability across different architectures and boards.

Throughout the technical specification and documentation of the RP2350, the Pico SDK is often referenced to explain hardware details, making it an important resource when implementing support for the RP2350 in RIOT OS. This influenced various parts of the implementation described in @chapter_implementation.

== ZephyrOS

In contrast to the Pico SDK, ZephyrOS is a full-fledged operating system for embedded devices, very similar to RIOT OS #footnote("ZephyrOS can be found here (Accessed 30.10.2025): https://github.com/zephyrproject-rtos/zephyr").
ZephyrOS is maintained by the Linux Foundation and has a large community of contributors.

While RIOT OS is historically largely developed in the context of academic research through volunteer contributions, ZephyrOS is backed by major industry players such as Google, Meta, ARM, Intel, Texas Instruments, Nordic, STMicroelectronics, and others #footnote("ZephyrOS project members (Accessed 28.10.2025): https://www.zephyrproject.org/project-members/").

This allows ZephyrOS to have vastly larger support for hardware platforms, architectures, and features compared to RIOT OS, supporting 881 boards as of October 2025 #footnote("ZephyrOS supported boards (Accessed 30.10.2025): https://docs.zephyrproject.org/latest/boards/index.html").

While working on this thesis, ZephyrOS added support for the RP2350, including Hazard3 support, by the end of September 2025 #footnote("ZephyrOS RP2350 Hazard support PR (Accessed 30.10.2025): https://github.com/zephyrproject-rtos/zephyr/pull/89758").
While this did not directly influence the work done in this thesis, it supported decisions made throughout the implementation process, as the approach in ZephyrOS aligned with the approach taken in this thesis regarding the abstraction of architectural differences between the ARM and RISC-V cores and handling the Hazard3 xh3irq interrupt controller (see @interrupt_handling_implementation).