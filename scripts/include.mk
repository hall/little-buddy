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
# Escape single quote for use in echo statements
escchar = $(subst $(squote),'\$(squote)',$1)


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

endif # __INCLUDE_MK__
