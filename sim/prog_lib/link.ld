OUTPUT_ARCH("riscv")

/* Default stack / test size */
_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x1000;
_TEST_SIZE  = DEFINED(_TEST_SIZE)  ? _TEST_SIZE  : 0x100;

/*****************************************************************************
 * Memory layout (each region 64 KB)
 *****************************************************************************/
MEMORY {
    MEM0 (rx) : ORIGIN = 0x00000000, LENGTH = 0x00010000
    MEM1 (rx) : ORIGIN = 0x00030000, LENGTH = 0x00010000
    MEM2 (rx) : ORIGIN = 0x000C0000, LENGTH = 0x00010000
    MEM3 (rx) : ORIGIN = 0x00300000, LENGTH = 0x00010000
    MEM4 (rx) : ORIGIN = 0x00C00000, LENGTH = 0x00010000

    /* rodata/data/bss/stack zone */
    MEM5 (rw) : ORIGIN = 0x03000000, LENGTH = 0x00010000

    /* golden/test zone */
    MEM6 (rw) : ORIGIN = 0x0C000000, LENGTH = 0x00010000
}

/* default entry */
ENTRY(_start)

/*****************************************************************************
 * Sections
 *****************************************************************************/
SECTIONS
{
    /**********************************************************************
     * Text sections to MEM0–MEM4
     **********************************************************************/
    .text0 : ALIGN(4) {
        _start = .;

        /* setup.S / reset handler / normal C text */
        setup.o(.text)
        *(.text)                /* setup.o + main if not sectioned */
        *(.text.startup*)
        *(.text.init*)
        *(.init)
        *(.fini)

        /* user-defined sectioned functions */
        *(.text0*)
    } > MEM0

    .text1 : ALIGN(4) {
        *(.text1*)
    } > MEM1

    .text2 : ALIGN(4) {
        *(.text2*)
    } > MEM2

    .text3 : ALIGN(4) {
        *(.text3*)
    } > MEM3

    .text4 : ALIGN(4) {
        *(.text4*)
    } > MEM4



    /**********************************************************************
     * rodata + data + sdata + bss + sbss unified in MEM5
     **********************************************************************/
    .data_m5 : ALIGN(4) {

        /* -------- rodata (const) -------- */
        __rodata_start = .;
        *(.rodata)
        *(.rodata.*)
        *(.gnu.linkonce.r.*)
        *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4)
        *(.srodata.cst2) *(.srodata*) 
        __rodata_end = .;

        /* -------- small data -------- */
        /* keep old-style gp symbol */
        _gp = . + 0x800;
        *(.sdata .sdata.* .gnu.linkonce.s.*)

        /* -------- normal data -------- */
        . = ALIGN(4);
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.gnu.linkonce.d.*)
        __data_end = .;

        /* -------- sbss/bss -------- */
        . = ALIGN(4);
        __sbss_start = .;
        *(.sbss)
        *(.sbss.*)
        *(.gnu.linkonce.sb.*)
        __sbss_end = .;

        . = ALIGN(4);
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.gnu.linkonce.b.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;

        /* -------- user-defined data block for MEM5 -------- */
        *(.data_m5*)

    } > MEM5


    /**********************************************************************
     * Optional test scratchpad
     * Reserve _TEST_SIZE bytes in MEM6
     **********************************************************************/
    .test_m6 (NOLOAD) : ALIGN(4) {
        _test_start = .;
        . += _TEST_SIZE;
        _test_end = .;
    } > MEM6


    /**********************************************************************
     * Golden output zone in MEM6
     **********************************************************************/
    .gold_m6 : ALIGN(4) {
        _gold_start = .;
        *(.gold_m6*)
        _gold_end = .;
    } > MEM6


    /**********************************************************************
     * Stack region (top of MEM5)
     **********************************************************************/
    .stack (NOLOAD) : ALIGN(4) {
        _stack_end = .;
        . += _STACK_SIZE;
        _stack = .;
        __stack = _stack;
    } > MEM5


    /**********************************************************************
    * 2x 64-bit performance counters + simulation end flag at tail of MEM6
    *
    * Layout (low -> high address within MEM6):
    *   [ _rdcycle_addr ] 8 bytes  (64-bit cycle counter)
    *   [ _rdinstr_addr ] 8 bytes  (64-bit instret counter)
    *   [   _sim_end    ] 4 bytes  (simulation end flag)
    **********************************************************************/
    . = ORIGIN(MEM6) + LENGTH(MEM6) - 20;

    _rdcycle_addr = .;
    . += 8;

    _rdinstr_addr = .;
    . += 8;

    _sim_end = .;
    . += 4;

    /* should now be exactly at the end of MEM6 */
    _end = .;
}

