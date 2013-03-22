all::

AR=ar

define LIB-template

ifndef $(1)-has-version
$(1)-has-version=0
ifdef version-map-$(1)
ifdef version-$(1)
$(1)-has-version=1
endif
endif
endif

short-soname-$(1)=lib$(1).so
$(foreach obj,$(libobj-$(1)),$(eval CFLAGS_$(obj)+=-fPIC))

ifeq ($$($(1)-has-version),1)
version-args-$(1) = -Wl,--version-script,$(version-map-$(1))
soname-$(1)=$$(short-soname-$(1)).$(version-$(1))

LIB-$(1) = $$(soname-$(1)) lib$(1).a

$$(soname-$(1)) : $$(version-map-$(1))

$$(short-soname-$(1)) : $$(soname-$(1))
	ln -sf $$< $$@
else
version-args-$(1) =
soname-$(1)=$$(short-soname-$(1))
endif

$$(soname-$(1)) : ALL_LDFLAGS += -shared -Wl,-soname=$$(soname-$(1)) $$(version-args-$(1))

TARGETS += $$(LIB-$(1))

endef


show-libs:
	@echo $(LIBS)

$(foreach lib,$(LIBS),$(eval $(call LIB-template,$(lib))))
include base.mk
