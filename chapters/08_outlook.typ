#import "../dependencies.typ": *

= Outlook <chapter_outlook>

== TrustZone-M and Security Features

The Cortex-M33 core of the RP2350 supports TrustZone-M. In her master thesis, Lena Boeckmann integrated TrustZone-M on the Cortex-M33 into RIOT @boeckmann:2025:secure-firmware.
This could be extended to the RP2350 port in the future. The author of the thesis even suggests the RP2350 as an interesting target for future work, due to the presence of both ARM security features, such as TrustZone-M and @pmp, on the RISC-V core.
While this thesis focused on getting a functional port of RIOT OS running on the RP2350, this can be seen as a stepping stone towards the aforementioned research into security features on heterogeneous architectures.

== Heterogeneous Core Utilization

Another interesting avenue for future work is to explore the potential of using both the RISC-V and Cortex-M33 cores in a Core0 and Core1 configuration, where Core0 (Cortex-M33) handles security-sensitive tasks through the Secure Mode support, while Core1 (RISC-V) manages less critical operations. The official Raspberry Pi documentation hints at this possibility but does not provide concrete examples or implementations, warning that it could be challenging on the software side @raspberrypi:2025:rp2350[Chapter~3.9.2].

== USB Support

In 2024, a `periph_usb` RIOT driver for the RP2040 was drafted. This could be finished and adapted to work on the RP2350 as well #footnote("The periph_usb driver draft (Accessed 27.10.2025): https://github.com/RIOT-OS/RIOT/pull/20817").
The `periph_usb` driver would allow RIOT applications running on the RP2350 to utilize its USB functionality, including UART over USB, which would lower the barrier to entry for developers wanting to experiment with RIOT on the RP2350.

== Advanced Multi-Core Features

In this thesis, we have only scratched the surface of multicore processing within RIOT OS. Future work could explore more advanced multicore features, such as inter-core communication mechanisms, load balancing, and task scheduling across cores. Currently, we avoid the scheduler, future work could explore how to extend the existing RIOT scheduler to be multicore aware, allowing it to distribute tasks between the two cores more effectively in a hardware-agnostic abstraction.
