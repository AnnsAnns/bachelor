#import "../dependencies.typ": *

= Introduction <chapter_introduction>

== Motivation

In recent years, ARM has dominated the embedded systems industry, offering relatively fast Microcontroller Units (MCUs) such as the Cortex-M series, at comparatively low prices.

The emergence of RISC-V has challenged that dominance by offering an open alternative, which allows anyone to design and manufacture their own RISC-V-based @mcu:pl without paying licensing fees to ARM.
This has led to a surge of innovation in the field of @mcu:pl, with many new designs and architectures being developed @Raghunathan:2021:History.

To ease developers into the usage of RISC-V based devices, Raspberry Pi released the RP2350 @mcu. This @mcu combines the legacy and wide adoption of the ARM Cortex-M33 with the flexibility of the new RISC-V architecture using a Hazard3 open-source core @raspberrypi:2025:rp2350.

This heterogeneous dual-core design is unified through an @mcu architecture that emphasizes a shared environment, including common @board peripherals, memory, and programmable I/O (@pio) blocks.
This makes the RP2350 a unique platform for experimenting with heterogeneous architectures in the embedded systems world.

RIOT OS is an open-source operating system designed for low-end IoT devices. It is known for its modularity, efficiency, and broad hardware support.
It is designed to be hardware-agnostic and portable across different architectures and boards @Baccelli_RIOT_An_Open_2018.
Still, RIOT OS currently does not support @mcu:pl with heterogeneous architectures such as the RP2350.

== Objective <chapter_objective>

This thesis explores the process of porting RIOT OS to the RP2350 @mcu, leveraging its unique dual-core architecture to enhance the capabilities of RIOT.
The goal is to implement a functional port that allows RIOT OS to run seamlessly on the RP2350, taking advantage of its heterogeneous architecture while maintaining the modularity and efficiency that RIOT OS prides itself on @Baccelli_RIOT_An_Open_2018.

The main objective of this work is to create a unified abstraction layer for both architectures that allows seamless switching between RISC-V and ARM with minimal code redundancy.
This entails exploring methods of integrating with the existing codebase of RIOT while also conforming to the unique peculiarities of the RP2350, such as the custom interrupt controller which the Hazard3 RISC-V processor includes.

In this thesis, we will also take a first glance at multicore processing within RIOT OS, exploring how a heterogeneous dual-core architecture can be utilized in an embedded operating system context.
The objective of this thesis is to have a functional RIOT OS port for the RP2350 that can serve as a foundation for future work and exploration of heterogeneous architectures in embedded systems.

== Outline

@chapter_background provides the relevant background information on the RP2350 architecture, and relevant concepts, such as heterogeneous architectures and programmable I/O, as well as its multicore processing.
It also gives an introduction to the RIOT operating system and design principles.

A review of related work in @chapter_related_work follows next.
In it, both related academic work and existing implementations of the RP2350 on other operating systems and libraries are discussed, with differences and similarities in our approach and goals being explained.

In @chapter_analysis the thesis analyzes the RP2350 in more detail to explore the requirements and design considerations that are relevant for the porting process. We examine the boot process, multicore startup sequence, and interrupt system in detail. We also explore RP2350-specific details such as the picobin image format and Hazard3 custom extensions.

After diving into these details, we then describe the implementation of the port in @chapter_implementation.
Detailing the steps taken to implement low-level support for the RP2350 architecture, including clock configuration. Describing the approach that was taken to implement multicore support and a unified abstraction for both architectures. We also discuss our approach to integrating the RP2350 interrupt controller with the existing RIOT interrupt handling system.

In @chapter_evaluation, we evaluate the functionality and performance of the RIOT OS port on the RP2350. Showcasing the benefits that a second core can bring to an embedded operating system. We also compare differences in performance and size between the ARM and RISC-V cores when running RIOT-OS.

Finally, @chapter_conclusion wraps up the thesis by summarizing the key findings and contributions of this work. We reflect on the challenges faced during the porting process and how they were addressed. We also discuss the implications of our work for the future of RIOT OS and heterogeneous architectures in embedded systems. Followed by a discussion of potential future directions and improvements that can be made based on the work of this thesis in @chapter_outlook.