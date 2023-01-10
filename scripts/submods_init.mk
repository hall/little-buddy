cur_makefile := $(lastword $(MAKEFILE_LIST))

$(cur_makefile): ;

SUBMODGOALS := $(sort $(foreach m, $(MAKECMDGOALS), \
  $(if $(filter-out ./,$(wildcard $(dir $m) $m)),$m,)))

ifneq ($(SUBMODGOALS),)
MAKECMDGOALS := $(filter-out $(SUBMODGOALS),$(MAKECMDGOALS))
SUBMODS := $(patsubst $(CURDIR)/%,%,$(SUBMODGOALS))
SUBMODS := $(patsubst %/,%,$(SUBMODS))
# Filter out subdirectories if their parent directories already in SUBMODS
SUBMODS := $(filter-out $(addsuffix /%,$(SUBMODS)),$(SUBMODS))
export SUBMODS
endif

