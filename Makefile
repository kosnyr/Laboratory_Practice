# STM32 project: GNU Arm Embedded GCC + OpenOCD
# Default controller: STM32F429ZI

TARGET_SERIES = STM32F429
TARGET_VERSION = ZI
DEBUG = 1
OPT = -Og

TARGET = $(TARGET_SERIES)$(TARGET_VERSION)
SUPPORTED_TARGETS = STM32F103C8 STM32F103C6 STM32F407VE STM32F411VE STM32F411CE STM32F411RE STM32F429ZI STM32F446RE

ifeq ($(filter $(TARGET),$(SUPPORTED_TARGETS)),)
$(error Unsupported controller: $(TARGET))
endif

BUILD_DIR = build_$(subst STM32,,$(TARGET))
CMSIS_INC = CMSIS/Include

# Controller-specific files and compiler options
ifeq ($(TARGET_SERIES),STM32F103)
SYS = CMSIS/Devices/STM32F1xx/Src/system_stm32f1xx.c \
      CMSIS/Devices/Src/syscalls.c \
      CMSIS/Devices/Src/sysmem.c
CMSIS_INC_DEV = CMSIS/Devices/STM32F1xx/Inc
MCPU = cortex-m3
MFPU = NONE
TRGT_CFG = stm32f1x

ifeq ($(TARGET_VERSION),C8)
ASM = STMDevices/STM32F103C8Tx/startup_stm32f103xb.s
CMSIS_INC_UNIT = CMSIS/Devices/STM32F1xx/Inc/STM32f103xB
LD = STMDevices/STM32F103C8Tx/STM32F103C8Tx_FLASH.ld
DEF = STM32F103xB
else
ASM = STMDevices/STM32F103x6/startup_stm32f103x6.s
CMSIS_INC_UNIT = CMSIS/Devices/STM32F1xx/Inc/STM32f103x6
LD = STMDevices/STM32F103x6/STM32F103X6_FLASH.ld
DEF = STM32F103x6
endif

else
SYS = CMSIS/Devices/STM32F4xx/Src/system_stm32f4xx.c \
      CMSIS/Devices/Src/syscalls.c \
      CMSIS/Devices/Src/sysmem.c
CMSIS_INC_DEV = CMSIS/Devices/STM32F4xx/Inc
MCPU = cortex-m4
MFPU = fpv4-sp-d16
TRGT_CFG = stm32f4x

ifeq ($(TARGET_SERIES),STM32F407)
ASM = STMDevices/STM32F407xx/startup_stm32f407xx.s
CMSIS_INC_UNIT = CMSIS/Devices/STM32F4xx/Inc/STM32F407xx
LD = STMDevices/STM32F407xx/STM32F407VETx_FLASH.ld
DEF = STM32F407xx

else ifeq ($(TARGET_SERIES),STM32F411)
ASM = STMDevices/STM32F411xe/startup_stm32f411xe.s
CMSIS_INC_UNIT = CMSIS/Devices/STM32F4xx/Inc/STM32F411xE
DEF = STM32F411xE

ifeq ($(TARGET_VERSION),VE)
LD = STMDevices/STM32F411xe/STM32F411VETx_FLASH.ld
else ifeq ($(TARGET_VERSION),CE)
LD = STMDevices/STM32F411xe/STM32F411CEUx_FLASH.ld
else ifeq ($(TARGET_VERSION),RE)
LD = STMDevices/STM32F411xe/STM32F411RETx_FLASH.ld
endif

else ifeq ($(TARGET_SERIES),STM32F429)
ASM = STMDevices/STM32F429xx/startup_stm32f429xx.s
CMSIS_INC_UNIT = CMSIS/Devices/STM32F4xx/Inc/STM32F429xx
LD = STMDevices/STM32F429xx/STM32F429ZITx_FLASH.ld
DEF = STM32F429xx

else ifeq ($(TARGET_SERIES),STM32F446)
ASM = STMDevices/STM32F446xx/startup_stm32f446xx.s
CMSIS_INC_UNIT = CMSIS/Devices/STM32F4xx/Inc/STM32F446xx
LD = STMDevices/STM32F446xx/STM32F446RETx_FLASH.ld
DEF = STM32F446xx
endif
endif

# Project sources
C_SOURCES = $(SYS) Core/Src/main.c
ASM_SOURCES = $(ASM)

# Compiler binaries: use PATH or make GCC_PATH="C:/path/to/bin"
PREFIX = arm-none-eabi-
ifdef GCC_PATH
CC = "$(GCC_PATH)/$(PREFIX)gcc"
AS = "$(GCC_PATH)/$(PREFIX)gcc" -x assembler-with-cpp
CP = "$(GCC_PATH)/$(PREFIX)objcopy"
SZ = "$(GCC_PATH)/$(PREFIX)size"
else
CC = $(PREFIX)gcc
AS = $(PREFIX)gcc -x assembler-with-cpp
CP = $(PREFIX)objcopy
SZ = $(PREFIX)size
endif

HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S
OPENOCD ?= openocd

# CPU and floating-point settings
CPU = -mcpu=$(MCPU)
FPU =
FLOAT_ABI =
ifneq ($(MFPU),NONE)
FPU = -mfpu=$(MFPU)
FLOAT_ABI = -mfloat-abi=hard
endif
MCU = $(CPU) -mthumb $(FPU) $(FLOAT_ABI)

C_DEFS = -D$(DEF)
AS_DEFS = -D$(DEF)
C_INCLUDES = -I$(CMSIS_INC_DEV) \
             -I$(CMSIS_INC_UNIT) \
             -I$(CMSIS_INC) \
             -ICore/Inc

CFLAGS = $(MCU) $(C_DEFS) $(C_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections
ASFLAGS = $(MCU) $(AS_DEFS) $(C_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections

ifeq ($(DEBUG),1)
CFLAGS += -g -gdwarf-2
ASFLAGS += -g -gdwarf-2
endif

CFLAGS += -MMD -MP -MF"$(@:%.o=%.d)"
ASFLAGS += -MMD -MP -MF"$(@:%.o=%.d)"

# Linker
LDSCRIPT = $(LD)
LIBS = -lc -lm -lnosys
LIBDIR =
LDFLAGS = $(MCU) -specs=nano.specs -T"$(LDSCRIPT)" $(LIBDIR) \
          -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref \
          -Wl,--gc-sections -Wl,--print-memory-usage

# Object files
OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(C_SOURCES:.c=.o)))
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(ASM_SOURCES:.s=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))
vpath %.s $(sort $(dir $(ASM_SOURCES)))

# Native Windows commands do not require rm or a Unix shell.
ifeq ($(OS),Windows_NT)
SHELL := cmd.exe
.SHELLFLAGS := /C
endif

.PHONY: all clean flash

all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin
	@echo "Build completed successfully."

$(BUILD_DIR)/%.o: %.c Makefile | $(BUILD_DIR)
	$(CC) -c $(CFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) "$<" -o "$@"

$(BUILD_DIR)/%.o: %.s Makefile | $(BUILD_DIR)
	$(AS) -c $(ASFLAGS) "$<" -o "$@"

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile $(LDSCRIPT) | $(BUILD_DIR)
	$(CC) $(OBJECTS) $(LDFLAGS) $(LIBS) -o "$@"
	$(SZ) "$@"

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(HEX) "$<" "$@"

$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(BIN) "$<" "$@"

$(BUILD_DIR):
ifeq ($(OS),Windows_NT)
	@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
else
	@mkdir -p "$(BUILD_DIR)"
endif

clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(BUILD_DIR)" rmdir /S /Q "$(BUILD_DIR)"
else
	@rm -rf "$(BUILD_DIR)"
endif

flash: all
	$(OPENOCD) -f interface/stlink.cfg -f target/$(TRGT_CFG).cfg -c "program $(BUILD_DIR)/$(TARGET).elf verify reset exit"
	@echo "Download completed successfully."

-include $(wildcard $(BUILD_DIR)/*.d)