CXX ?= g++
CXXFLAGS ?= -std=c++17 -O3 -Wall -Wextra -Wpedantic -Werror
LDFLAGS ?=
QS_DIR ?= $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)/quickshell
TARGETS = theme.switcher sysmon

.PHONY: all clean
all: $(TARGETS)

theme.switcher: theme.switcher.cpp
	$(CXX) $(CXXFLAGS) -MMD -MP $(LDFLAGS) -o $@ $< -lcrypto

sysmon: $(QS_DIR)/native/sysmon.cpp
	$(CXX) $(CXXFLAGS) -MMD -MP $(LDFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS) theme.switcher.d sysmon.d

-include theme.switcher.d sysmon.d
