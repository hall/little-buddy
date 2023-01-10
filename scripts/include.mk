ifndef __INCLUDE_MK__
__INCLUDE_MK__ := 1

cur_makefile := $(lastword $(MAKEFILE_LIST))

$(cur_makefile): ;

####
# Generic definitions

# Convenient variables
lparen	:= (
rparen	:= )
comma   := ,
quote   := "
squote  := '
empty   :=
space   := $(empty) $(empty)

devnull := /dev/null

###
# Remove/copy commands
CMDRMFILE	= rm -f $1
CMDRMFILER	= find $1 $(RCS_FIND_IGNORE) \
		   \( $(addprefix -name ,'$(firstword $2)') \
		      $(addprefix -o -name ',$(addsuffix ',$(filter-out $(firstword $2),$2))) \) \
		    -type f -print | xargs rm -f
CMDRMDIR	= rm -fr $1
CMDCPFILE	= cp -f $1 $2

###
# Build-in obj suffix
ifeq ($(BUILT-IN-OBJ),1)
built_in_suffix := .o
else
built_in_suffix := .a
endif

###
# Name of target with a '.' as filename prefix. foo/bar.o => foo/.bar.o
dot-target = $(dir $(1)).$(notdir $(1))

###
# The temporary file to save gcc -MF generated dependencies must not
# contain a comma
get_depfile_name = $(subst $(comma),_,$(dot-target).d)
depfile = $(call get_depfile_name,$@)

###
# filename of target with directory and extension stripped
basetarget = $(basename $(notdir $@))

###
# filename of first prerequisite with directory and extension stripped
baseprereq = $(basename $(notdir $<))

###
# Escape single quote for use in echo statements
escchar = $(subst $(squote),'\$(squote)',$1)

###
# Easy method for doing a status message
       kecho := :
 quiet_kecho := echo
silent_kecho := :
kecho := $($(quiet)kecho)

echo-help = @echo '  $(call escchar,$(1))'

###
# try-run
try-run = $(shell if ($(1)) >$(devnull) 2>&1; \
                  then echo "$(2)"; \
                  else echo "$(3)"; \
                  fi)

###
# cc-option
cc-option = $(call try-run, \
	$(CC) $(KBUILD_CPPFLAGS) $(KBUILD_CFLAGS) $(1) -c -x c \
		-o $(devnull) $(devnull),$(1),$(2))

###
# Shorthand for $(Q)$(MAKE) -f scripts/build.mk obj=
# Usage:
# $(Q)$(MAKE) $(build)=dir
build := -f $(srctree)/scripts/build.mk obj

# Prefix -I with $(srctree) if it is not an absolute path.
# skip if -I has no parameter
#addtree = $(if $(patsubst -I%,%,$(1)), \
#$(if $(filter-out -I/%,$(1)),$(patsubst -I%,-I$(srctree)/%,$(1))) $(1))
addtree = $(if $(patsubst -I%,%,$(1)), \
    $(if $(filter-out -I/%,$(1)),$(patsubst -I%,-I$(srctree)/%,$(1)),$(1)))

# Find all -I options and call addtree
flags = $(foreach o,$($(1)),$(if $(filter -I%,$(o)),$(call addtree,$(o)),$(o)))

# echo command.
# Short version is used, if $(quiet) equals `quiet_', otherwise full one.
echo-cmd = $(if $($(quiet)cmd_$(1)),\
	echo '  $(call escchar,$($(quiet)cmd_$(1)))$(echo-why)' ;)
echo-cmd-nowhy = $(if $($(quiet)cmd_$(1)),\
	echo '  $(call escchar,$($(quiet)cmd_$(1)))' ;)

# printing commands
cmd = @$(echo-cmd) $(cmd_$(1))

# Add $(obj)/ for paths that are not absolute
objectify = $(foreach o,$(1),$(if $(filter /%,$(o)),$(o),$(obj)/$(o)))

###
# if_changed      - execute command if any prerequisite is newer than
#                   target, or command line has changed
# if_changed_dep  - as if_changed, but uses fixdep to reveal dependencies
#                   including used config symbols
# if_changed_rule - as if_changed but execute rule instead
# See Documentation/kbuild/makefiles.txt for more info

ifneq ($(KBUILD_NOCMDDEP),1)
# Check if both arguments has same arguments. Result is empty string if equal.
# User may override this check using make KBUILD_NOCMDDEP=1
arg-check = $(strip $(filter-out $(cmd_$(1)), $(cmd_$@)) \
                    $(filter-out $(cmd_$@),   $(cmd_$(1))) )
else
arg-check = $(if $(strip $(cmd_$@)),,1)
endif

# Replace >$< with >$$< to preserve $ when reloading the .cmd file
# (needed for make)
# Replace >#< with >\#< to avoid starting a comment in the .cmd file
# (needed for make)
# Replace >'< with >'\''< to be able to enclose the whole string in '...'
# (needed for the shell)
make-cmd = $(call escchar,$(subst \#,\\\#,$(subst $$,$$$$,$(cmd_$(1)))))

# Find any prerequisites that is newer than target or that does not exist.
# PHONY targets skipped in both cases.
any-prereq = $(filter-out $(PHONY),$?) $(filter-out $(PHONY) $(wildcard $^),$^)

depfile-new = printf '\n%s\n' 'cmd_$@ := $(make-cmd)' > $(depfile)
depfile-add = printf '\n%s\n' 'cmd_$@ := $(make-cmd)' >> $(depfile)

# Execute command if command has changed or prerequisite(s) are updated.
#
if_changed = $(if $(strip $(any-prereq) $(arg-check)),                       \
	@ ( $(echo-cmd) $(cmd_$(1)) ) &&                                     \
	  ( $(depfile-new) ))

if_changed2 = $(if $(strip $(any-prereq) $(call arg-check,$(2))),             \
	@ ( $(call echo-cmd,$(1)) $(cmd_$(1)) && \
	    $(call echo-cmd,$(2)) $(cmd_$(2)) ) &&                           \
	  ( $(call depfile-new,$(2)) ))

# Execute the command and also postprocess generated .d dependencies file.
if_changed_dep = $(if $(strip $(any-prereq) $(arg-check)),                   \
	@ ( $(echo-cmd) $(cmd_$(1)) ) &&                                     \
	  ( $(depfile-add) ))

# Usage: $(call if_changed_rule,foo)
# Will check if $(cmd_foo) or any of the prerequisites changed,
# and if so will execute $(rule_foo).
if_changed_rule = $(if $(strip $(any-prereq) $(arg-check)),                  \
	@ ( $(rule_$(1)) ) &&                                                \
	  ( $(depfile-add) ))

###
# why - tell why a a target got build
#       enabled by make V=2
#       Output (listed in the order they are checked):
#          (1) - due to target is PHONY
#          (2) - due to target missing
#          (3) - due to: file1.h file2.h
#          (4) - due to command line change
#          (5) - due to missing .cmd file
#          (6) - due to target not in $(targets)
# (1) PHONY targets are always build
# (2) No target, so we better build it
# (3) Prerequisite is newer than target
# (4) The command line stored in the file named dir/.target.cmd
#     differed from actual command line. This happens when compiler
#     options changes
# (5) No dir/.target.d file (used to store command line)
# (6) No dir/.target.d file and target not listed in $(targets)
#     This is a good hint that there is a bug in the kbuild file
ifeq ($(KBUILD_VERBOSE),2)
why =                                                                        \
    $(if $(filter $@, $(PHONY)),- due to target is PHONY,                    \
        $(if $(wildcard $@),                                                 \
            $(if $(strip $(any-prereq)),- due to: $(any-prereq),             \
                $(if $(arg-check),                                           \
                    $(if $(cmd_$@),- due to command line change,             \
                        $(if $(filter $@, $(targets)),                       \
                            - due to missing .d file,                        \
                            - due to $(notdir $@) not in $$(targets)         \
                         )                                                   \
                     )                                                       \
                 )                                                           \
             ),                                                              \
             - due to target missing                                         \
         )                                                                   \
     )

echo-why = $(call escchar, $(strip $(why)))
endif

endif # __INCLUDE_MK__
