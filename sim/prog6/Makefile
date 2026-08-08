ELF_NAME := main

export CROSS_PREFIX ?= riscv64-unknown-elf-
export RISCV_GCC ?= $(CROSS_PREFIX)gcc
export RISCV_OBJDUMP ?= $(CROSS_PREFIX)objdump -xsd
export RISCV_OBJCOPY ?= $(CROSS_PREFIX)objcopy -O verilog

LIB_DIR := ../prog_lib
LDFILE := $(LIB_DIR)/link.ld 
CFLAGS := -march=rv32imf -mabi=ilp32 -I$(LIB_DIR)
LDFLAGS := -static -nostdlib -nostartfiles -march=rv32imf -mabi=ilp32 -T$(LDFILE) -lgcc
VPATH := .:$(LIB_DIR)

SRC_C := $(notdir $(wildcard *.c $(LIB_DIR)/*.c))
SRC_S := $(notdir $(wildcard *.S $(LIB_DIR)/*.S))
OBJ_C := $(patsubst %.c,%.o,$(SRC_C))
OBJ_S := $(patsubst %.S,%.o,$(SRC_S))
SRC := $(SRC_C) $(SRC_S)
OBJ := $(OBJ_C) $(OBJ_S)


.SUFFIXES: .o .S .c

.PHONY: all

all: bulid_bmp_header show_bmp build_elf build_log build_hex

bulid_bmp_header: 
	python3 bmp_to_header.py

show_bmp: 
	python3 show_tiny_image.py

build_elf: $(OBJ) | $(LDFILE)
	$(RISCV_GCC) $^ $(LDFLAGS) -o $(ELF_NAME)

build_log: $(ELF_NAME)
	$(RISCV_OBJDUMP) $< > $(ELF_NAME).log

build_hex: $(ELF_NAME)
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .text0 --change-addresses 0 $(ELF_NAME) mem0.hex || true
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .text1 --change-addresses -0x00030000 $(ELF_NAME) mem1.hex || true
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .text2 --change-addresses -0x000C0000 $(ELF_NAME) mem2.hex || true
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .text3 --change-addresses -0x00300000 $(ELF_NAME) mem3.hex || true
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .text4 --change-addresses -0x00C00000 $(ELF_NAME) mem4.hex || true
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .data_m5 --change-addresses -0x03000000 $(ELF_NAME) mem5.hex || true
	$(RISCV_OBJCOPY) -i 1 -b 0 -j .gold_m6 --change-addresses -0x0C000000 $(ELF_NAME) mem6.hex || true


%.o: %.S
	$(RISCV_GCC) -c $(CFLAGS) $^

%.o: %.c
	$(RISCV_GCC) -c $(CFLAGS) $^

.PHONY: clean

clean:
	rm -rf $(ELF_NAME) $(ELF_NAME).log $(ELF_NAME)*.hex mem*.hex *.o test_image.h


