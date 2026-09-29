CXX ?= g++
CXXFLAGS ?= -std=c++17 -O3 -Wall -Wextra -Wpedantic -Werror
LDFLAGS ?=
QS_DIR ?= $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)/quickshell
TARGETS = theme.switcher wallpick sysmon

.PHONY: all clean
all: $(TARGETS)

theme.switcher: theme.switcher.cpp
	$(CXX) $(CXXFLAGS) -MMD -MP -MF $@.d -MT $@ $(LDFLAGS) -o $@ $<

wallpick: wallpick.cpp
	$(CXX) $(CXXFLAGS) -MMD -MP -MF $@.d -MT $@ $(LDFLAGS) -o $@ $<

sysmon: $(QS_DIR)/native/sysmon.cpp
	$(CXX) $(CXXFLAGS) -MMD -MP -MF $@.d -MT $@ $(LDFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS) theme.switcher.d wallpick.d sysmon.d

-include theme.switcher.d wallpick.d sysmon.d
