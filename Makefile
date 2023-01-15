# Check if just to show the help content
ifeq ($(MAKECMDGOALS),help)
HELP_TARGET := 1
endif

export LANGUAGE := en

ifneq ($(HELP_TARGET),1)
# We are using a recursive build, so we need to do a little thinking
# to get the ordering right.
#
# Most importantly: sub-Makefiles should only ever modify files in
# their own directory. If in some directory we have a dependency on
# a file in another dir (which doesn't happen often, but it's often
# unavoidable when linking the built-in.o targets which finally
# turn into elf file), we will call a sub make in that other dir, and
# after that we are sure that everything which is in that other dir
# is now up to date.
#
# The only cases where we need to modify files which have global
# effects are thus separated out and done before the recursive
# descending is started. They are now explicitly listed as the
# prepare rule.

# KBUILD_SRC is set on invocation of make in OBJ directory
# KBUILD_SRC is not intended to be used by the regular user (for now)
ifeq ($(KBUILD_SRC),)

export KBUILD_ROOT := $(CURDIR)

# OK, Make called in directory where kernel src resides
# Do we want to locate output files in a separate directory?
export KBUILD_OUTPUT := $(CURDIR)/out

# That's our default target when none is given on the command line
PHONY := _all
_all:

# Cancel implicit rules on the config file
$(KBUILD_OUTPUT)/.config: ;

ifneq ($(KBUILD_OUTPUT),)
# Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
saved-output := $(KBUILD_OUTPUT)
KBUILD_OUTPUT := $(shell mkdir -p $(KBUILD_OUTPUT) && cd $(KBUILD_OUTPUT) \
                         && pwd)

$(if $(KBUILD_OUTPUT),, \
     $(error failed to create output directory "$(saved-output)"))

PHONY += $(MAKECMDGOALS) sub-make

$(filter-out _all sub-make $(CURDIR)/Makefile, $(MAKECMDGOALS)) _all: sub-make
	@:

include $(CURDIR)/scripts/submods_init.mk


# Look for make include files relative to root of kernel src
MAKEFLAGS += --include-dir=$(CURDIR)

sub-make: FORCE
	@echo MAKE START: $(shell date +"%Y-%m-%d %T.%N")
	$(Q)$(MAKE) -C $(KBUILD_OUTPUT) KBUILD_SRC=$(CURDIR) \
		-f $(CURDIR)/Makefile $(filter-out _all sub-make,$(MAKECMDGOALS))
	@echo MAKE END: $$(date +"%Y-%m-%d %T.%N")
	@printf "MAKE TIME: %.2f seconds\n" $$(echo "$$(date +%s.%N) - $(shell date +"%s.%N")" | bc)

# Leave processing to above invocation of make
skip-makefile := 1
endif # ifneq ($(KBUILD_OUTPUT),)
endif # ifeq ($(KBUILD_SRC),)

# We process the rest of the Makefile if this is the final invocation of make
ifeq ($(skip-makefile),)

# Do not print "Entering directory ...",
# but we want to display it when entering to the output directory
# so that IDEs/editors are able to understand relative filenames.
MAKEFLAGS += --no-print-directory

# If building an external module we do not care about the all: rule
# but instead _all depend on modules
PHONY += all
_all: all

ifeq ($(KBUILD_SRC),)
        # building in the source tree
        srctree := .
else
        ifeq ($(KBUILD_SRC)/,$(dir $(CURDIR)))
                # building in a subdirectory of the source tree
                srctree := ..
        else
                ifeq ($(KBUILD_SRC)/,$(dir $(patsubst %/,%,$(dir $(CURDIR)))))
                        srctree := ../..
                else
                        srctree := $(KBUILD_SRC)
                endif
        endif
endif
objtree		:= .
src		:= $(srctree)
obj		:= $(objtree)

VPATH		:= $(srctree)

export srctree objtree VPATH

GIT_DIRTY := $(shell (git diff --quiet && git diff --cached --quiet) >/dev/null 2>&1 || echo -dirty)
GIT_REVISION := $(shell (which git >/dev/null 2>&1) && (git rev-parse --short HEAD 2>/dev/null))$(GIT_DIRTY)


# Cross compiling and selecting different set of gcc/bin-utils
# ---------------------------------------------------------------------------
#
# When performing cross compilation for other architectures ARCH shall be set
# to the target architecture. (See arch/* for the possibilities).
# ARCH can be set during invocation of make:
# make ARCH=ia64
# Another way is to have ARCH set in the environment.
# The default ARCH is the host where make is executed.

# CROSS_COMPILE specify the prefix used for all executables used
# during compilation. Only gcc and related bin-utils executables
# are prefixed with $(CROSS_COMPILE).
# CROSS_COMPILE can be set on the command line
# make CROSS_COMPILE=ia64-linux-
# Alternatively CROSS_COMPILE can be set in the environment.
# A third alternative is to store a setting in .config so that plain
# "make" in the configured kernel build directory always uses that.
# Default value for CROSS_COMPILE is not to prefix executables
# Note: Some architectures assign CROSS_COMPILE in their arch/*/Makefile
ARCH		    ?= arm
CROSS_COMPILE	?= arm-none-eabi-

# SHELL used by kbuild
CONFIG_SHELL := $(shell if [ -x "$$BASH" ]; then echo $$BASH; \
          else if [ -x bash ]; then echo bash; \
          else echo sh; fi ; fi)

# Make variables (CC, etc...)
AS		= $(CROSS_COMPILE)as
CC		= $(CROSS_COMPILE)gcc
CPP		= $(CC) -E
C++		= $(CROSS_COMPILE)g++
LD		= $(CC)
#LD		= $(CROSS_COMPILE)ld
AR		= $(CROSS_COMPILE)ar
NM		= $(CROSS_COMPILE)nm
STRIP	= $(CROSS_COMPILE)strip
OBJCOPY	= $(CROSS_COMPILE)objcopy
OBJDUMP	= $(CROSS_COMPILE)objdump

AWK		= awk
PERL	= perl
PYTHON	= python

KBUILD_CPPFLAGS :=

KBUILD_CFLAGS	:= -fno-common -fmessage-length=0 -Wall \
		   -fno-exceptions -ffunction-sections \
		   -fdata-sections -fomit-frame-pointer

# By default char on ARM platform is unsigned char, but char on x86 platform
# is signed char. To avoid porting issues, force char to be signed char
# on ARM platform.
KBUILD_CFLAGS	+= -fsigned-char

# 1) Avoid checking out-of-bound array accesses in a loop
#    (and unrolling/peeling/exiting the loop based on the check)
# 2) Avoid detecting paths dereferencing a NULL pointer
#    (and turning the problematic statement into a trap)
KBUILD_CFLAGS	+= -fno-aggressive-loop-optimizations \
		   -fno-isolate-erroneous-paths-dereference
# Treat floating-point constants as float instead of double
KBUILD_CFLAGS	+= -fsingle-precision-constant
KBUILD_CFLAGS	+= -Wdouble-promotion -Wfloat-conversion

KBUILD_CFLAGS	+= -g

#C_ONLY_FLAGS	:= -std=gnu89
C_ONLY_FLAGS	:= -std=gnu99

C++_ONLY_FLAGS	:= -std=gnu++98 -fno-rtti

KBUILD_AFLAGS   := -D__ASSEMBLY__

export ARCH CROSS_COMPILE AS LD CC
export CPP C++ AR NM STRIP OBJCOPY OBJDUMP
export MAKE AWK PERL PYTHON

export KBUILD_CPPFLAGS NOSTDINC_FLAGS OBJCOPYFLAGS LDFLAGS
export KBUILD_CFLAGS
export KBUILD_AFLAGS
export KBUILD_ARFLAGS
export C_ONLY_FLAGS C++_ONLY_FLAGS

# Files to ignore in find ... statements

export RCS_FIND_IGNORE := \( -name SCCS -o -name BitKeeper -o -name .svn -o    \
			  -name CVS -o -name .pc -o -name .hg -o -name .git \) \
			  -prune -o
export RCS_TAR_IGNORE := --exclude SCCS --exclude BitKeeper --exclude .svn \
			 --exclude CVS --exclude .pc --exclude .hg --exclude .git

# ===========================================================================
# Build targets only.

# Objects we will link into $(IMAGE_FILE) / subdirs we need to visit
init-y		:= init/
core-y		:= main/

LDS_FILE	:= best1000.lds

# Link flags for all LD processes
LINK_CFLAGS	:=
export LINK_CFLAGS

# Link flags for image only
LIB_LDFLAGS		:=
CFLAGS_IMAGE	:= -static
LDFLAGS_IMAGE	:= -X --no-wchar-size-warning

# Include target definitions
include $(srctree)/config/target.mk
include $(srctree)/config/common.mk

$(srctree)/config/target.mk: ;
$(srctree)/config/common.mk: ;

ifneq ($(filter-out %/,$(init-y) $(core-y)),)
$(error The object files cannot be linked at top level: $(filter-out %/,$(init-y) $(core-y)))
endif

ifneq ($(NO_BUILDID),1)
LDFLAGS_IMAGE	+= --build-id
endif
ifeq ($(CROSS_REF),1)
LDFLAGS_IMAGE	+= --cref
endif

REAL_LDS_FILE := $(LDS_FILE)

# Generate REVISION_INFO (might be defined in target)
ifeq ($(REVISION_INFO),)
REVISION_INFO := $(GIT_REVISION)
endif

include $(srctree)/scripts/include.mk

REVISION_INFO := $(subst $(space),-,$(strip $(REVISION_INFO)))
SOFTWARE_VERSION := $(subst $(space),-,$(strip $(SOFTWARE_VERSION)))

$(info -------------------------------)
$(info REVISION_INFO: $(REVISION_INFO))
$(info -------------------------------)

# Build host and user info
export BUILD_HOSTNAME := $(shell hostname -s)
export BUILD_USERNAME := $(shell id -un)

BUILD_HOSTNAME := $(subst $(space),-,$(strip $(BUILD_HOSTNAME)))
BUILD_USERNAME := $(subst $(space),-,$(strip $(BUILD_USERNAME)))

# Default kernel image to build when no specific target is given.
# IMAGE_FILE may be overruled on the command line or
# set in the environment
IMAGE_FILE ?= firmware-$(LANGUAGE).elf

ifneq ($(filter .map .bin .hex .lst,$(suffix $(IMAGE_FILE))),)
$(error Invalid IMAGE_FILE (conflicted suffix): $(IMAGE_FILE))
endif

LST_SECTION_OPTS :=
LST_SECTION_NAME :=
ifneq ($(LST_ONLY_SECTION),)
LST_SECTION_OPTS += $(foreach m,$(subst $(comma),$(space),$(LST_ONLY_SECTION)),-j $m )
LST_SECTION_NAME := _$(subst *,+,$(subst !,-,$(LST_ONLY_SECTION)))
endif
ifneq ($(LST_RM_SECTION),)
LST_SECTION_OPTS += $(foreach m,$(subst $(comma),$(space),$(LST_RM_SECTION)),-R $m )
LST_SECTION_NAME := $(LST_SECTION_NAME)_no_$(subst *,+,$(subst !,-,$(LST_RM_SECTION)))
endif

IMAGE_MAP := $(addsuffix .map,$(basename $(IMAGE_FILE)))
IMAGE_BIN := $(addsuffix .bin,$(basename $(IMAGE_FILE)))
STR_BIN   := $(addsuffix .str,$(basename $(IMAGE_FILE)))
IMAGE_HEX := $(addsuffix .hex,$(basename $(IMAGE_FILE)))
ifeq ($(LST_SECTION_OPTS),)
IMAGE_LST := $(addsuffix .lst,$(basename $(IMAGE_FILE)))
else
IMAGE_LST := $(addsuffix $(LST_SECTION_NAME).lst,$(basename $(IMAGE_FILE)))
IMAGE_SEC := $(addsuffix $(LST_SECTION_NAME)$(suffix $(IMAGE_FILE)),$(basename $(IMAGE_FILE)))
endif

LDS_TARGET := _$(notdir $(REAL_LDS_FILE))

IMAGE_VER  := build_info.o

targets := $(LDS_TARGET) $(IMAGE_FILE) $(IMAGE_BIN) $(STR_BIN) $(IMAGE_LST) $(IMAGE_VER)
cmd_files := $(wildcard $(foreach f,$(targets),$(call get_depfile_name,$(f))))

ifneq ($(cmd_files),)
include $(cmd_files)
$(cmd_files): ;
endif

# The all: target is the default when no target is given on the
# command line.
# This allow a user to issue only 'make' to build a kernel including modules
# Defaults to $(IMAGE_BIN)
ifeq ($(TRACE_STR_SECTION),1)
all: $(IMAGE_BIN) $(STR_BIN) ;
else
all: $(IMAGE_BIN) ;
endif

      cmd_gen-IMAGE_BIN = $(OBJCOPY) -R .trc_str -O binary $< $@

$(IMAGE_BIN): $(IMAGE_FILE)
ifneq ($(filter 1,$(COMPILE_ONLY) $(NO_BIN)),)
	@:
else
	+$(call if_changed,gen-IMAGE_BIN)
endif

      cmd_gen-STR_BIN = $(OBJCOPY) -j .code_start_addr -j .rodata_str  -j .trc_str \
          --change-section-lma .code_start_addr=0x00000000 \
          --change-section-lma .rodata_str=0x00000010 \
          --change-section-lma .trc_str=0x00008000 \
          -O binary $< $@

$(STR_BIN): $(IMAGE_FILE)
ifneq ($(filter 1,$(COMPILE_ONLY) $(NO_BIN)),)
	@:
else
	+$(call if_changed,gen-STR_BIN)
endif

      cmd_gen-IMAGE_HEX = $(OBJCOPY) -O ihex $< $@

$(IMAGE_HEX): $(IMAGE_FILE)
ifeq ($(COMPILE_ONLY),1)
	@:
else
	+$(call if_changed,gen-IMAGE_HEX)
endif

PHONY += lst lst_only
lst lst_only: $(IMAGE_LST) ;

ifneq ($(filter lst_only,$(MAKECMDGOALS)),)
NO_COMPILE := 1
endif

ifeq ($(LST_SECTION_OPTS),)
      cmd_gen-IMAGE_LST = $(OBJDUMP) -Sldx $< > $@
else
      cmd_gen-IMAGE_LST = $(OBJCOPY) $(LST_SECTION_OPTS) $< $(IMAGE_SEC) && $(OBJDUMP) -Sldx $(IMAGE_SEC) > $@
endif

$(IMAGE_LST): $(IMAGE_FILE)
	+$(call if_changed,gen-IMAGE_LST)


# Flags

# warn about C99 declaration after statement
#C_ONLY_FLAGS    += -Wdeclaration-after-statement

# disallow errors like 'EXPORT_GPL(foo);' with missing header
C_ONLY_FLAGS   += -Werror=implicit-int

# require functions to have arguments in prototypes, not empty 'int foo()'
#C_ONLY_FLAGS    += -Werror=strict-prototypes

C_ONLY_FLAGS    += -Werror-implicit-function-declaration

# Prohibit date/time macros, which would make the build non-deterministic
KBUILD_CFLAGS   += -Werror=date-time

KBUILD_CFLAGS   += -Wlogical-op

#KBUILD_CFLAGS   += -Wno-address-of-packed-member

KBUILD_CFLAGS	+= -Wno-trigraphs \
		   -fno-strict-aliasing \
		   -Wno-format-security

#KBUILD_CFLAGS	+= Wundef

# use the deterministic mode of AR if available
KBUILD_ARFLAGS := D

include $(srctree)/scripts/extrawarn.mk

# Add user supplied CPPFLAGS, AFLAGS and CFLAGS as the last assignments
KBUILD_CPPFLAGS += $(KCPPFLAGS)
KBUILD_AFLAGS += $(KAFLAGS)
KBUILD_CFLAGS += $(KCFLAGS)

IMAGE-dirs	:= $(patsubst %/,%,$(filter %/, $(init-y) $(core-y)))

submodgoals =
ifneq ($(SUBMODS),)
include $(srctree)/scripts/submods.mk

IMAGE-builddirs	:= $(call get_subdirs,$(IMAGE-dirs),$(SUBMODS))
ifeq ($(COMPILE_ONLY),1)
submodgoals = $(call get_submodgoals,$@,$(SUBMODS))
endif
else
IMAGE-builddirs	:= $(IMAGE-dirs)
endif

IMAGE-alldirs	:= $(sort $(IMAGE-dirs) $(patsubst %/,%,$(filter %/, \
			$(init-) $(core-) $(extra-))))

init-y		:= $(patsubst %/, %/built-in$(built_in_suffix), $(init-y))
core-y		:= $(patsubst %/, %/built-in$(built_in_suffix), $(core-y))

IMAGE_INIT := $(init-y)
IMAGE_MAIN := $(core-y)

ifeq ($(NO_COMPILE),1)
IMAGE-deps :=
else
IMAGE-deps := $(LDS_TARGET) $(IMAGE_INIT) $(IMAGE_MAIN) $(IMAGE_VER)
endif

BUILD_INFO_FLAGS := \
	-DREVISION_INFO=$(REVISION_INFO) \
	-DFLASH_SIZE=$(FLASH_SIZE) \
	-DOTA_UPGRADE_CRC_LOG_SIZE=$(OTA_UPGRADE_CRC_LOG_SIZE) \
	-DNV_REC_DEV_VER=$(NV_REC_DEV_VER) \
	-I$(srctree)/platform/hal

BUILD_INFO_FLAGS += $(LDS_SECTION_FLAGS)
BUILD_INFO_FLAGS += -DCHIP=$(CHIP)

ifneq ($(CHIP_SUBTYPE),)
BUILD_INFO_FLAGS += -DCHIP_SUBTYPE=$(CHIP_SUBTYPE)
endif
ifneq ($(SOFTWARE_VERSION),)
BUILD_INFO_FLAGS += -DSOFTWARE_VERSION=$(SOFTWARE_VERSION)
endif
ifneq ($(OTA_BOOT_SIZE),0)
BUILD_INFO_FLAGS += -DOTA_BOOT_SIZE=$(OTA_BOOT_SIZE)
endif
ifneq ($(OTA_CODE_OFFSET),)
BUILD_INFO_FLAGS += -DOTA_CODE_OFFSET=$(OTA_CODE_OFFSET)
endif
ifneq ($(OTA_REMAP_OFFSET),)
BUILD_INFO_FLAGS += -DOTA_REMAP_OFFSET=$(OTA_REMAP_OFFSET)
endif
ifeq ($(CRC32_OF_IMAGE),1)
BUILD_INFO_FLAGS += -DCRC32_OF_IMAGE
endif
ifeq ($(TRACE_CRLF),1)
BUILD_INFO_FLAGS += -DTRACE_CRLF
endif

BUILD_INFO_FLAGS += -DKERNEL=$(KERNEL)

      cmd_image_ver = $(CC) $(filter-out -Werror=date-time, \
                             $(call flags,KBUILD_CPPFLAGS) \
                             $(call flags,KBUILD_CFLAGS) \
                             $(call flags,C_ONLY_FLAGS) \
                             $(NOSTDINC_FLAGS)) \
                             $(BUILD_INFO_FLAGS) \
                             -MD -MP -MF $(depfile) -MT $@ \
                             -c -o $@ $<

IMAGE_VER_SRC := $(src)/utils/build_info/build_info.c

$(IMAGE_VER): $(IMAGE_VER_SRC) $(filter-out $(IMAGE_VER),$(IMAGE-deps)) FORCE
	$(call if_changed_dep,image_ver)

# Linker scripts preprocessor (.lds.S -> .lds)
# ---------------------------------------------------------------------------
      cmd_cpp_lds_S = $(CPP) $(call flags,KBUILD_CPPFLAGS) \
                             $(call flags,CPPFLAGS_$(LDS_FILE)) \
                             -MD -MP -MF $(depfile) -MT $@ \
                             $(NOSTDINC_FLAGS) \
                             -P -C -E -x c -o $@ $<

LDS_SRC_STEM := $(src)/scripts/link/$(REAL_LDS_FILE)
LDS_SRC := $(firstword $(wildcard $(LDS_SRC_STEM).S $(LDS_SRC_STEM).sx) $(LDS_SRC_STEM).S)

$(LDS_TARGET): $(LDS_SRC) FORCE
	$(call if_changed_dep,cpp_lds_S)

PHONY += lds
lds: $(LDS_TARGET) ;


# Final link of $(IMAGE_FILE)
# ---------------------------------------------------------------------------
#
# 1) Link the archives twice to solve circular references between two or
#    more archives. Otherwise we should use --start-group and --end-group
#    options. Normally, an archive is searched only once in the order that
#    it is specified on the command line.
# 2) Use --whole-archive option to solve weak symbol overriding issue.
#    It tells LD to include every object file in the archive in the link,
#    rather than searching the archive for the required object files.
#    By default the strong symbols defined in the archive will not override
#    any weak symbol, for LD only searches the archive if there is a undefined
#    symbol (and a weak symbol is considered as a defined symbol).
#
      cmd_link-IMAGE_FILE = $(LD) -o $@ \
		  $(LD_USE_PATCH_SYMBOL) \
	      -T $(LDS_TARGET) \
	      $(CFLAGS_IMAGE) \
	      -Wl,$(subst $(space),$(comma),$(strip \
	      $(LDFLAGS) $(LDFLAGS_IMAGE) \
	      -Map=$(IMAGE_MAP) \
	      --gc-sections \
	      --whole-archive)) \
	      $(IMAGE_INIT) $(IMAGE_MAIN) $(IMAGE_VER) \
	      -Wl,--no-whole-archive $(LIB_LDFLAGS) $(LIB_LDFLAGS)
		  


# Include targets which we want to
# execute if the rest of the kernel build went well.
$(IMAGE_FILE): $(IMAGE-deps) FORCE
ifneq ($(filter 1,$(COMPILE_ONLY) $(NO_COMPILE)),)
	@:
else
	+$(call if_changed,link-IMAGE_FILE)
endif

ifneq ($(IMAGE-deps),)
# The actual objects are generated when descending,
# make sure no implicit rule kicks in
$(sort $(filter %/built-in$(built_in_suffix),$(IMAGE-deps))): $(IMAGE-builddirs) ;
endif

# Handle descending into subdirectories listed in $(IMAGE-dirs)
# Preset locale variables to speed up the build process. Limit locale
# tweaks to this spot to avoid wrong language settings when running
# make menuconfig etc.
# Error messages still appears in the original language

PHONY += $(IMAGE-dirs)
$(IMAGE-dirs): scripts
	$(Q)$(MAKE) $(build)=$@ $(submodgoals)

# clean - Delete most, but leave enough to build external modules
#
clean: rm-dirs  := $(CLEAN_DIRS)
clean: rm-files := $(CLEAN_FILES)
ifneq ($(SUBMODS),)
clean-dirs      := $(addprefix _clean_, $(IMAGE-builddirs))
else
clean-dirs      := $(addprefix _clean_, $(IMAGE-alldirs))
endif

PHONY += $(clean-dirs) clean IMAGE-clean
$(clean-dirs):
	$(Q)$(MAKE) $(clean)=$(patsubst _clean_%,%,$@)

IMAGE-clean:
	$(Q)$(call CMDRMFILE,$(IMAGE_FILE) $(IMAGE_MAP) \
		$(IMAGE_BIN) $(STR_BIN) $(IMAGE_HEX) $(IMAGE_LST) \
		$(IMAGE_VER) $(LDS_TARGET))

clean: IMAGE-clean

clean: $(clean-dirs)
	$(call cmd,rmdirs)
	$(call cmd,rmfiles)
ifeq ($(SUBMODS),)
	$(Q)$(call CMDRMFILER,.,*.o *.a *.s *.d)
endif

ifeq ($(SUBMODS),)
      cmd_clean    = $(call CMDRMDIR,$(KBUILD_OUTPUT))
clean:
	+$(call cmd,clean)
endif

      cmd_predefined-macros = $(CPP) $(filter-out -I% -D% -include%,$(KBUILD_CPPFLAGS) $(KBUILD_CFLAGS) $(C_ONLY_FLAGS)) \
                                     -x c -E -dM -o $@ $(devnull)

PREDEF_MACRO_FILE := predefined-macros.txt

$(PREDEF_MACRO_FILE): FORCE
	$(call cmd,predefined-macros)

PHONY += predefined-macros
predefined-macros: $(PREDEF_MACRO_FILE) ;

# FIXME Should go into a make.lib or something
# ===========================================================================

      cmd_rmdirs = $(if $(wildcard $(rm-dirs)),$(call CMDRMDIR,$(rm-dirs)))

      cmd_rmfiles = $(if $(wildcard $(rm-files)),$(call CMDRMFILE,$(rm-files)))

# Shorthand for $(Q)$(MAKE) -f scripts/clean.mk obj=dir
# Usage:
# $(Q)$(MAKE) $(clean)=dir
clean := -f $(srctree)/scripts/clean.mk obj

# Generate tags for editors
# ---------------------------------------------------------------------------
      cmd_tags = $(CONFIG_SHELL) $(srctree)/tools/tags.sh $@

tags TAGS cscope gtags: FORCE
	$(call cmd,tags)

endif # ifeq ($(skip-makefile),)
endif # ifneq ($(HELP_TARGET),1)

# Help target
ifneq ($(HELP_TARGET),)
ifeq ($(HELP_TARGET),1)
include scripts/include.mk
endif

help: FORCE
	@echo "  all             - Build all targets"
	@echo "  lst             - Build the mixed source/assembly file of the final image"
	@echo "  lds             - Build the linker script file"
	@echo "  <dir/file>      - Build specified file(s) only"
	@echo "  clean           - Remove generated files"

endif # ifneq ($(HELP_TARGET),)

# Cancel implicit rules on top Makefile
ifeq ($(KBUILD_SRC),)
$(CURDIR)/Makefile Makefile: ;
else
$(KBUILD_SRC)/Makefile Makefile: ;
endif

PHONY += FORCE
FORCE: ;

# Declare the contents of the .PHONY variable as phony.  We keep that
# information in a variable so we can use it in if_changed and friends.
.PHONY: $(PHONY)
