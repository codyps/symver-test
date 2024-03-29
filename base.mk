## base.mk: bbdcc92+, see https://github.com/jmesmon/trifles.git
# Usage:
#
# == For use by the one who runs 'make' ==
# $(V)              when defined, prints the commands that are run.
# $(CFLAGS)         expected to be overridden by the user or build system.
# $(LDFLAGS)        same as CFLAGS, except for LD.
#
# == Required in the makefile ==
# all::		    place this target at the top.
# $(obj-sometarget) the list of objects (generated by CC) that make up a target
#                   (in the list TARGET).
# $(TARGETS)        a list of binaries (the output of LD).
#
# == Optional (for use in the makefile) ==
# $(NO_INSTALL)     when defined, no install target is emitted.
# $(ALL_CFLAGS)     non-overriden flags. Append (+=) things that are absolutely
#                   required for the build to work into this.
# $(ALL_LDFLAGS)    same as ALL_CFLAGS, except for LD.
#		    example for adding some library:
#
#			sometarget: ALL_LDFLAGS += -lrt
#
# $(CROSS_COMPILE)  a prefix on gcc. "CROSS_COMPILE=arm-linux-" (note the trailing '-')

# TODO:
# - install disable per target.
# - flag tracking per target.'.obj.o.cmd'
# - flag tracking that easily allows adding extra variables.
# - profile guided optimization support.
# - output directory support ("make O=blah")
# - build with different flags placed into different output directories.
# - library building (shared & static)

# Delete the default suffixes
.SUFFIXES:

O = .
#VPATH = $(O)
$(foreach target,$(TARGETS),$(eval vpath $(target) $(O)))

.PHONY: all FORCE
all:: $(TARGETS)

# FIXME: overriding in Makefile is tricky
CC = $(CROSS_COMPILE)gcc
CXX= $(CROSS_COMPILE)g++
LD = $(CC)
RM = rm -f

ifdef DEBUG
OPT=-O0
else
OPT=-Os
endif

ifndef NO_LTO
ALL_CFLAGS  ?= -flto
ALL_LDFLAGS ?= $(ALL_CFLAGS) $(OPT) -fuse-linker-plugin
else
ALL_CFLAGS ?= $(OPT)
endif

ALL_CFLAGS += -ggdb3

COMMON_CFLAGS += -Wall
COMMON_CFLAGS += -Wundef -Wshadow
COMMON_CFLAGS += -pipe
COMMON_CFLAGS += -Wcast-align
COMMON_CFLAGS += -Wwrite-strings
COMMON_CFLAGS += -Wunsafe-loop-optimizations
COMMON_CFLAGS += -Wnormalized=id

ALL_CFLAGS += -std=gnu99
ALL_CFLAGS += -Wbad-function-cast
ALL_CFLAGS += -Wstrict-prototypes -Wmissing-prototypes

ALL_CFLAGS   += $(COMMON_CFLAGS) $(CFLAGS)
ALL_CXXFLAGS += $(COMMON_CFLAGS) $(CXXFLAGS)

ALL_LDFLAGS += -Wl,--build-id
ALL_LDFLAGS += $(LDFLAGS)

ifndef V
	QUIET_CC   = @ echo '  CC  ' $@;
	QUIET_CXX  = @ echo '  CXX ' $@;
	QUIET_LINK = @ echo '  LINK' $@;
	QUIET_LSS  = @ echo '  LSS ' $@;
	QUIET_SYM  = @ echo '  SYM ' $@;
endif

# Avoid deleting .o files
.SECONDARY:

obj-to-dep = $(foreach obj,$(1),$(dir $(obj)).$(notdir $(obj)).d)
target-dep = $(addprefix $(O)/,$(call obj-to-dep,$(obj-$(1))))
target-obj = $(addprefix $(O)/,$(obj-$(1)))

# flags-template flag-prefix vars message
# Defines a target '.TRACK-$(flag-prefix)FLAGS'.
# if $(ALL_$(flag-prefix)FLAGS) or $(var) changes, any rules depending on this
# target are rebuilt.
vpath .TRACK_%FLAGS $(O)
define flags-template
TRACK_$(1)FLAGS = $$($(2)):$$(subst ','\'',$$(ALL_$(1)FLAGS))
$(O)/.TRACK-$(1)FLAGS: FORCE
	@FLAGS='$$(TRACK_$(1)FLAGS)'; \
	if test x"$$$$FLAGS" != x"`cat $(O)/.TRACK-$(1)FLAGS 2>/dev/null`" ; then \
		echo 1>&2 "    * new $(3)"; \
		echo "$$$$FLAGS" >$(O)/.TRACK-$(1)FLAGS; \
	fi
TRASH += $(O)/.TRACK-$(1)FLAGS
endef

$(eval $(call flags-template,C,CC,c build flags))
$(eval $(call flags-template,CXX,CXX,c++ build flags))
$(eval $(call flags-template,LD,LD,link flags))

obj-cflags = CFLAGS_$(1)

$(O)/%.o: %.c .TRACK-CFLAGS
	$(QUIET_CC)$(CC)   -MMD -MF $(call obj-to-dep,$@) -c -o $@ $< $(ALL_CFLAGS)

$(O)/%.o: %.cc .TRACK-CXXFLAGS
	$(QUIET_CXX)$(CXX) -MMD -MF $(call obj-to-dep,$@) -c -o $@ $< $(call obj-clfags,$*) $(ALL_CXXFLAGS)

define BIN-LINK
$(1)/$(2) : .TRACK-LDFLAGS $(obj-$(2))
	$$(QUIET_LINK)$(LD) -o $$@ $(call target-obj,$(2)) $(ALL_LDFLAGS) $(ldflags-$(2))
endef

$(foreach target,$(TARGETS),$(eval $(call BIN-LINK,$(O),$(target))))

ifndef NO_INSTALL
PREFIX  ?= $(HOME)   # link against things here
DESTDIR ?= $(PREFIX) # install into here
BINDIR  ?= $(DESTDIR)/bin
.PHONY: install %.install
%.install: %
	install $* $(BINDIR)/$*
install: $(foreach target,$(TARGETS),$(target).install)
endif

.PHONY: clean %.clean
%.clean :
	$(RM) $(call target-obj,$*) $(O)/$* $(TRASH) $(call target-dep,$*)

clean:	$(addsuffix .clean,$(TARGETS))

.PHONY: watch
watch:
	@while true; do \
		make -rR --no-print-directory; \
		inotifywait -q \
		  \
		 -- $$(find . \
		        -name '*.c' \
			-or -name '*.h' \
			-or -name 'Makefile' \
			-or -name '*.mk' ); \
		echo "Rebuilding..."
	done

show-targets:
	@echo $(TARGETS)

deps = $(foreach target,$(TARGETS),$(call target-dep,$(target)))
-include $(deps)
