#import "../dependencies.typ": *

= Implementation<chapter_implementation>

In this chapter, we discuss the implementation of the RP2350 port in RIOT OS. Going through the various notable components that were implemented, including the module setup, interrupt handling, multicore support, and clock configuration.

The full source code of the implementation can be found on GitHub for Picotool #footnote("The picotool integration PR (Accessed 21.10.2025): https://github.com/RIOT-OS/RIOT/pull/21269"),
ARM support
#footnote("The ARM RP2350 port PR (Accessed 21.10.2025): https://github.com/RIOT-OS/RIOT/pull/21545"),
Multicore
#footnote("The Multicore code (Accessed 21.10.2025): https://github.com/AnnsAnns/RIOT/blob/pico2_riscv/cpu/rp2350/core.c")
and RISC-V support
#footnote("The RISC-V and Interrupts RP2350 port PR (Accessed 21.10.2025): https://github.com/RIOT-OS/RIOT/pull/21753").

== Module Setup and Abstraction

RIOT OS already has support for both ARM and RISC-V architectures in the form of shared common folders.

In order to avoid code duplication, the RP2350 includes a secondary common abstraction module. This module, referred to as `rp2350_common`, contains nearly all the code that is shared between both architectures. This includes peripheral drivers, riot-specific definitions, and general initialization functions.

=== Module Structure

The standard procedure of adding new @mcu:pl or @board:pl to RIOT OS is to create a CPU-specific module within the `cpu` directory and a @board specific module within the `boards` directory.
These modules then include the common code from the `common` directory. They can also offer peripheral support from the `periph` directory, such as GPIO or UART drivers.

#figure(
  placement: auto,
  image("../figures/riot_module_setup.drawio.pdf"),
  caption: [RIOT OS RP2350 module folder structure.
    Blue denotes architecture-specific modules.
    Orange denotes CPU module definitions.
    Green denotes @board module definitions.
  ],
) <riot_module_setup>

The general layout of the implementation of the RP2350 support in RIOT can be seen in figure @riot_module_setup. The rpi-pico-2 @board includes its architecture-specific module, which then includes the shared `rp2350_common` module.

=== Build System Architecture Abstraction

The shared `rp2350_common` configures itself based on the defined architecture, either ARM or RISC-V, through defines provided by the RIOT build system, including the import of the architecture-specific common folder.

Architecture-specific function calls are handled through abstraction layers via define flags provided by the RIOT build system.
For example, IRQ enabling is done through the `rp_irq_enable` function, which inlines the appropriate function call based on the current architecture, as shown in @rp_irq_enable_code. Using `static inline` allows the compiler to optimize away the function call overhead, resulting in efficient architecture specific code generation while still maintaining a clean and centralized abstraction.

#figure(
  placement: auto,
  [
    ```c
    /**
     * @brief     Enable the given IRQ
     * @param[in] irq_no IRQ number to enable
     */
    static inline void rp_irq_enable(uint32_t irq_no)
    {
    #ifdef RP2350_USE_RISCV
        xh3irq_enable_irq(irq_no);
    #else
        NVIC_EnableIRQ(irq_no);
    #endif
    }
    ```
  ],
  caption: [Example of architecture-specific IRQ enabling through abstraction in `rp2350_common`.],
) <rp_irq_enable_code>

This centralized design allows for the architecture-specific code to be kept to a minimum.
The CPU module itself has to create the `cpu_init` function, which is called by the RIOT kernel during startup. The ARM implementation only requires @arm_cpu_init_code within the architecture-specific CPU module.

#figure(
  placement: auto,
  [
    ```c
    #include "cpu.h"
    #include "periph_cpu.h"

    void cpu_init(void)
    {
        cortexm_init();
        rp2350_init();
    }
    ```
  ],
  caption: [Example of the ARM `cpu_init` function within the `rp2350_common` module.],
) <arm_cpu_init_code>

This function then calls both the architecture-specific initialization function and the shared `rp2350_init` initialization function (@rp2350_init_code), which handles the initialization of the RP2350 itself.

#figure(
  placement: auto,
  [
    ```c
    /**
     * @brief Initialize the CPU, set IRQ priorities, clocks, and peripherals
     */
    void rp2350_init(void)
    {
        /* Reset GPIO state */
        gpio_reset();
        /* Reset clock to default state */
        clock_reset();
        /* initialize the CPU clock */
        cpu_clock_init();
        /* initialize the early peripherals */
        early_init();
        /* trigger static peripheral initialization */
        periph_init();
        /* initialize the board */
        board_init();
    }
    ```
  ],
  caption: [The shared `rp2350_init` function within the `rp2350_common` module. Initializes clocks, GPIO, and peripherals.],
) <rp2350_init_code>

=== Build System

The build system of RIOT is built upon the `Makefile` system. Each module can provide a `Makefile.include`, `Makefile.dep`, `Makefile.features`, and a general `Makefile` file, which is then included by the RIOT build system when the module is used. This allows for easy configuration of the build system, including the addition of source files, include paths, and defines.

The main purpose of the per-CPU module is to provide the correct values for the architecture. For example, the RISC-V version needs to define that it supports the RISC-V specific xh3irq and @pmp peripherals as shown in @riscv_cpu_makefile.

#figure(
  [
    ```Makefile
    CPU_CORE := rv32imac
    CPU_FAM     := RP2350
    CPU_MODEL   = rp2350_hazard3

    FEATURES_PROVIDED += periph_pmp
    FEATURES_PROVIDED += periph_xh3irq

    include $(RIOTCPU)/rp2350_common/Makefile.features
    include $(RIOTCPU)/riscv_common/Makefile.features
    ```
  ],
  caption: [Example of the RISC-V CPU module `Makefile` including the shared `rp2350_common` and `riscv_common` feature files.],
) <riscv_cpu_makefile>

=== Picobin Integration

To avoid the maintenance burden of a custom linker script, we chose the design in @image_partition_definition_analysis to modify the common linker script to include a hook for the picobin section using the `KEEP` directive to ensure that the picobin block is not discarded during the linking process, but not included when building for other platforms, being an optional addition.

The picobin block must be located within the first 4kB of flash memory. To ensure this, we place the picobin block directly after the interrupt vector table, which is typically located at the beginning of the flash memory region, as shown in the excerpt from the modified linker script in @picobin_linker_script_excerpt.

#figure(
    [
```ld
sfixed = .;
_isr_vectors = DEFINED(_isr_vectors) ? _isr_vectors : . ;
KEEP(*(SORT(.vectors*)))
KEEP(*(SORT(.picobin_block*))) /* Keep picobin block used by RP2350 */
*(.text .text.* .gnu.linkonce.t.*)
```
    ],
    caption: [Excerpt of modified linker script from `cortexm_common` module to include picobin block]
) <picobin_linker_script_excerpt>

We do a similar modification (@picobin_riscv_linker_script_excerpt) for the RISC-V linker script within the `riscv_common` module to ensure that both architectures support picobin when building for the RP2350. Since RISC-V does not have a vector table at the start of flash, we simply place the picobin block at the beginning.

#figure(
[```ld
.text           :
{
  KEEP(*(SORT(.picobin_block*)))
  *(.text.unlikely .text.unlikely.*)
  *(.text.startup .text.startup.*)
  *(.text .text.*)
  *(.gnu.linkonce.t.*)
} >flash AT>flash :flash
```],
  caption: [Excerpt of modified linker script from `riscv_common` module to include picobin block]
) <picobin_riscv_linker_script_excerpt>

The picobin block itself is a pure Assembly file called `picobin.s` that the RIOT build system automatically includes when building the RP2350 as described in @picobin_assembly_code.

If in the future this structure needs to be appended, e.g., to support both RISC-V and ARM with a single binary, this file can be easily modified to include multiple picobin blocks as needed based on the settings explained in @image_partition_definition_analysis.


#figure(
  placement: auto,
  [```asm
.section .picobin_block, "a" /* "a" means "allocatable" (can be moved by the linker) */

/* PICOBIN_BLOCK_MARKER_START */
.word 0xffffded3
    /* ITEM 0 START based on 5.9.3.1 */
    .byte 0x42 /* (size_flag == 0, item_type == PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE) */
    .byte 0x1 /* Block Size in words */
    /* image_type_flags (2 bytes) [See 5.9.3.1 / p419] */
    /* 15 -> 0 (1 for "Try before you buy" image */
    /* 12-14 -> 001 (RP2350 = 1) */
    /* 11 -> 0 (Reserved) */
    /* 8-10 -> 001 (EXE_CPU_ARM == 000) || (EXE_CPU_RISCV == 001) */
    /* 6-7 -> 00 (Reserved) */
    /* 4-5 -> 10 (2) EXE Security */
    /* 0-3 // 0001 IMAGE_TYPE_EXE */
    .hword 0b0001000100100001
    /* ITEM 0 END see 5.1.5.1 for explanation and 5.9.5.1 for the value / structure */
    .byte 0xff /* PICOBIN_BLOCK_ITEM_2BS_LAST */
    .hword 0x0001 /* Size of the item in words (predefined value) */
    .byte 0x00 /* Padding */
    /* Next Block Pointer */
    .word 0x00000000 /* Next block pointer (0 means no more blocks) */
/* PICOBIN_BLOCK_MARKER_END */
.word 0xab123579 /* Marker for the end of the picobin block */
  ```],
  caption: [Assembly code for the picobin block used in RP2350 builds, based on the definitions in @image_partition_definition_analysis.]
) <picobin_assembly_code>

== Interrupt Handling <interrupt_handling_implementation>

To facilitate an easy abstraction to registering @isr:pl for both architectures, `rp2350_common` provides a shared vector table full of function pointers. Given that typical programs will not want to define all 51 @isr:pl, all entries are initialized to a default handler that causes a core panic.

To make these functions rewritable, all of them are defined with the `weak` and `alias` attributes. When the compiler sees a function with the same name defined elsewhere, it will use that function instead of the default one.

For example, if the user wants to define a @isr for the UART0 peripheral, they can define a function with the name `isr_uart0` and the compiler will use that function instead of the default one.

=== RISC-V Interrupt Handling

On initialization, the riscv_common startup function `riscv_init` sets the standard trap entry point through the `mtvec` @CSR to the `trap_entry` function. This function is then called on every interrupt or exception (commonly referred to as traps in RISC-V).

The `trap_entry` then saves the stack and calls the `trap_handler` function, which then handles the actual interrupt. On other RISC-V devices, this function would then call the handler for @PLIC or @CLIC, however, since the RP2350 uses the custom XH3IRQ controller, it was necessary to implement our own handler.

To make future ports of Hazard3-based devices easier, the port implements the handler within the `riscv_common` module itself. This allows for easier reuse of the code in future projects, thus reducing implementation effort.

Similar to @PLIC and @CLIC, the XH3IRQ controller can be enabled through the common RIOT `periph` abstraction layer. Any device that runs on RISC-V and includes the XH3IRQ controller can include the `periph_xh3irq` feature in its CPU module and get support for the XH3IRQ controller.

When enabled, the `trap_handler` checks the `xh3irq_has_pending` function whether the Machine Interrupt Pending @CSR has any pending interrupts, as shown in @meip_check_code.
If this is the case, the `trap_handler` in @xh3irq_handler_code then calls `xh3irq_handler`, which uses the shared vector table to call the appropriate @isr for the pending interrupt depending on the highest priority written within the `MEINEXT` @CSR.

#figure(
  placement: auto,
[
```c
/**
 * Hazard3 has internal registers to individually filter which
 * external IRQs appear in meip. When meip is 1,
 * this indicates there is at least one external interrupt
 * which is asserted (hence pending in mieipa), enabled in meiea,
 * and of priority greater than or equal to the current
 * preemption level in meicontext.preempt.
 */
#define MEIP_OFFSET 11

/*
* Get MEIP which is the external interrupt pending bit
* from the Machine Interrupt Pending Register address
*/
uint32_t mip_reg = read_csr(0x344);
uint32_t meip = bit_check32(&mip_reg, MEIP_OFFSET);
```
],
  caption: [Checking the Machine Interrupt Pending @CSR for pending interrupts in `trap_handler`.],
) <meip_check_code>

#figure(
[
```c
/*
* Get MEINEXT at 0xbe4, which is the next highest interrupt to handle (Bit 2-10).
* This will also automatically clear the interrupt (See 3.8.6.1.2.)
*
* Contains the index of the highest-priority external interrupt
* which is both asserted in meipa and enabled in meiea, left-
* shifted by 2 so that it can be used to index an array of 32-bit
* function pointers. If there is no such interrupt, the MSB is set.
*/
uint32_t meinext = (read_csr(0xBE4) >> MEINEXT_IRQ_OFFSET) & MEINEXT_MASK;

void (*isr)(void) = (void (*)(void)) vector_cpu[meinext];
```
],
  caption: [Fetching the highest priority pending interrupt from the `MEINEXT` @CSR and calling the appropriate @isr from the shared vector table in `xh3irq_handler`.],
) <xh3irq_handler_code>

=== ARM Interrupt Handling

As with the RISC-V interrupt handling, the port aims to conform to the existing RIOT-OS abstractions as closely as possible.

The `cortexm_common` module already includes the necessary setup for the @NVIC, including the default vector table and the `cortexm_init` function, which is called during startup to initialize the @NVIC.

To allow amendments to the vector table, `cortexm_common` uses an attribute system to give all vector table amendment arrays the `section(".vectors." # x )` attribute that the linker script can then sort and properly place within the final binary.

== Multicore Implementation <multicore_implementation>

The very first step is to wake up the secondary core. The secondary core remains dormant after the initial boot sequence and expects a specific sequence of events for wake up.
For that, the RP2350 needs to release the reset state of the core. This can be done by a simple write to the `FRCE_ON` register of the @psm, followed by polling the `DONE` register of the @psm till the software has a confirmation that the reset has completed @raspberrypi:2025:rp2350[Chapter~7.4.4].

At this point, the secondary core is in a known state, awaiting further instructions. The port then uses the inter-processor FIFOs described in @inter_processor_fifos to send the necessary startup information to the secondary core to boot it up.
In total, the startup sequence sends six 32-bit values to the secondary core in the order specified in @multicore_boot_values.

#figure(
  table(
    columns: 2,
    align: (left, left),
    [*Value*], [*Description*],
    [1-3], [`0`, `0`, `1`],
    [4], [Pointer to ISR vector],
    [5], [Initial stack pointer],
    [6], [Entry point address (Trampoline function)],
  ),
  caption: [Values sent to the secondary core via inter-processor FIFO during boot.],
) <multicore_boot_values>

A trampoline function is a small piece of code that sets up the environment for the actual function to be called, thus allowing for more complex setups, such as setting up the stack or registers before jumping to the actual function. Thus the handler functions also writes the function and argument to the stack of the secondary core before sending the stack pointer value.
To send these values, it follows a specific sequence of steps to ensure that the secondary core receives them correctly.
After @multicore_fifo_sequence_code has completed, the secondary core should be awake and running the trampoline function at the provided entry point address.

The trampoline function then calls the architecture-specific initialization function, pops both values from the stack, and jumps to the provided entry point function with the provided argument.
In the design of this entry function interface, we decided to conform to the way threads are started in RIOT OS. In essence, this means that the entry function needs to have a signature of `void *(*core_1_fn_t)(void *arg)`.
The current implementation is designed to offload a specific, blocking task to the secondary core as described in the analysis in @riot_threading_multicore_analysis.


#figure(
  [
    ```c
    uint32_t seq = 0;
    /** We iterate through the cmd_sequence till we covered every param
     * (seq does not increase with each loop, thus we need to while loop this) */
    while(seq < 6) {
        uint32_t cmd = cmd_sequence[seq];
        /* If the cmd is 0 we need to drain the READ FIFO first*/
        if(cmd == 0) {
            /* Drain READ FIFO till it is empty */
            while(SIO->FIFO_ST & 1<<SIO_FIFO_READ_VALID_BIT) {
                (void) SIO->FIFO_RD; /* Table 39 FIFO_RD*/
            };
            fifo_unblock_processor();
        }
        /* Check whether queue is full */
        while (!(SIO->FIFO_ST & 1<<SIO_FIFO_SEND_READY_BIT)) {
            /* Wait for queue space */
        }
        SIO->FIFO_WR = cmd; /* Write data since we know we have space */
        fifo_unblock_processor(); /* Send event */
        /* This is eq. to the SDK multicore_fifo_pop_blocking_inline*/
        /* We check whether there are events */
        while(!(SIO->FIFO_ST & 1<<SIO_FIFO_READ_VALID_BIT)) {
            /* If not we wait */
            fifo_block_processor();
        };
        /* Get the event since this is our response */
        volatile uint32_t response = SIO->FIFO_RD;
        /* move to next state on correct response (echo-d value)
         * otherwise start over */
        seq = cmd == response ? seq + 1 : 0;
    };
    ```
  ],
  caption: [Sequence to send the necessary boot values to the secondary core via inter-processor FIFO. First, draining the read FIFO if the value to send is `0`, then sending the value and waiting for an echoed response before proceeding to the next value. On each incorrect response, the sequence is restarted.
  ],
) <multicore_fifo_sequence_code>

== Implementation of Clocks

The RP2350 provides multiple clock sources, initially running from the @ROSC (See: @rosc_analysis). The implementation provides a clock initialization function within `rp2350_common` that handles the switch to the more stable @XOSC (See: @xosc_analysis) and then switch the system clock, reference clock, and other clocks to the desired frequencies.

This function first initializes the @XOSC by setting the appropriate bits within the `XOSC CTRL` register to enable it and waits for it to stabilize. The RP2350 uses 12-bit magic value codes for this to protect against accidental writes. These differ depending on the desired frequency range of the crystal being used @raspberrypi:2025:rp2350[Chapter~8.2.8].
After configuring the startup delay timer based on the crystal frequency and desired stabilization time @raspberrypi:2025:rp2350[Chapter~8.2.4], the @XOSC can be enabled and polled until stable.

At this point, the initialization sequence configures the @pll to run off the @XOSC as the reference clock. The feedback and post divider values are calculated based on the desired @vco frequency and final @pll output frequency of 125 MHz @raspberrypi:2025:rp2350[Chapter~8.1.6.1].
The port then sets the system clock to run off the @pll output and the peripheral clock to run through the lower line provided by the system clock.
The complete clock initialization sequence is encapsulated in the `cpu_clock_init()` function within `rp2350_common`, as shown in @rp2350_init_code.

To allow for modifications to the set clock speed, the port provides all these values as `#define` flags, allowing for easy adjustments to the clock speed if the user desires a different configuration, e.g. to save power by running at a lower frequency as discussed in @clock_analysis_design.
The implementation then asserts that any entered values are within the valid ranges specified in the RP2350 datasheet to avoid misconfigurations that could lead to undefined behavior or at worst hardware damage.

== #gls(long: true, "pio") Support <pio_implementation>

@pio support requires some modification to existing RIOT OS drivers, most notably the GPIO driver. @pio state machines can have direct access to GPIO pins, which requires the GPIO driver to configure the pins accordingly.
In RIOT OS, the GPIO driver `gpio_init` function takes two arguments, the pin number and the mode. The mode is defined as a set of flags that configure the pin as input/output, pull-up/down, etc., however, @pio functionality serves as an additional mode.

The easiest way to do this is to redefine these aforementioned flags to include @pio functionality. The RIOT design already considered such scenarios and wrapped the definition with `#ifndef HAVE_GPIO_MODE_T` guards, allowing us to redefine the `gpio_mode_t` enum within the `rp2350_common` module, adding additional flags for PIO0/PIO1 respectively.
We can then simply check for these flags within the `gpio_init` function and configure the pin accordingly for @pio functionality by setting the appropriate bits within the `PIO_CTRL` register of the RP2350.
The user can then configure the desired pins as PIO0/PIO1 and use the existing @pio driver to configure and use the @pio state machines as needed.

=== Abstracting @pio Instruction Generation

To facilitate usage of @pio within RIOT OS, we implemented an abstraction layer for generating @pio instructions. This layer provides a set of functions that allow users to create @pio programs without needing to write raw @pio assembly code. Specifically, we use C Macros to define common @pio instructions, making it easier to construct @pio programs programmatically, as shown in @pio_instruction_example for the uncondition `JMP` jump instruction.

This ensures that the generated instructions are correct and reduces the likelihood of errors when writing @pio programs as compared with writing raw binary values.

#figure(
  placement: auto,
[```c
#define PIO_JMP_COND_ALWAYS     (0)     /**< Always jump */
/**
 * @brief JMP instruction encoding
 *
 * Set program counter to address if condition is true.
 *
 * @param[in] cond      Condition (PIO_JMP_COND_*)
 * @param[in] addr      Target address (0-31)
 */
#define PIO_JMP(cond, addr) \
    (0b0000000000000000 | (((cond) & 0b111) << 5) | ((addr) & 0b11111))
/**
 * @brief JMP - unconditional jump
 *
 * @param[in] addr  Target address (0-31)
 */
#define PIO_JMP_ALWAYS(addr)    PIO_JMP(PIO_JMP_COND_ALWAYS, (addr))
```]
  ,
  caption: [Example of C macros to generate @pio instructions, specifically the `JMP` instruction with conditional and unconditional variants.]
) <pio_instruction_example>

The resulting macro output can then be directly written into the instruction memory of the @pio state machines. Alternatively, if users want to use the pico sdk @pio assembler, they can still do so by including the necessary headers. This way, our own @pio support remains vendor agnostic and does not rely on the pico sdk while still allowing users to leverage existing tools if desired.

=== @pio Usage Example

Through the abstractions provided, a simple @pio program such as @pio_usage_example can be created with minimal effort fully within RIOT OS, without a need to write raw @pio assembly code or binary values. The code in the example initializes a @pio program that generates a square wave on GPIO0 by setting the pin high and low in a loop. While not a complex example, it demonstrates the ease of use provided by the @pio abstraction layer within RIOT OS.

#figure(
  placement: auto,
[```c
static const uint16_t squarewave_program_instructions[] = {
    PIO_SET_PINDIRS(1),
    PIO_SET_PINS(1),
    PIO_SET_PINS(0),
    PIO_JMP_ALWAYS(1),
};

int main(void) {
    // Load instructions
    for (uint32_t i = 0; i < 4; ++i) {
        *(&PIO0->INSTR_MEM0 + i)
            = squarewave_program_instructions[i];
    }
    // Set the Clock Divider for SM0
    PIO0->SM0_CLKDIV = (uint32_t) (1.0f * (1 << 16)); //12.5 MHz
    // Configure the Pin Control for SM0
    PIO0->SM0_PINCTRL = (1 << PIO_SM0_PINCTRL_SET_COUNT_LSB) |
        (0 << PIO_SM0_PINCTRL_SET_BASE_LSB);
    // Initialize GPIO0 for PIO usage
    gpio_init(0, GPIO_PIO0);
    // Set SM0 to enabled
    atomic_set(&PIO0->CTRL, 1 << PIO_CTRL_SM_ENABLE_LSB);
}
```]
  ,
  caption: [Example of using the @pio abstraction layer to create a simple square wave generator on GPIO0 using PIO0. The program sets the pin high and low in a loop, creating a square wave output. The GPIO pin is initialized for @pio usage using the modified GPIO driver.]
) <pio_usage_example>