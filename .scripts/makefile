# Compiler & Flags
CXX = g++
CXXFLAGS = -std=c++98 -O3 -Wall -Wextra

# Paths
HOME_DIR = $(HOME)
QS_DIR = $(HOME_DIR)/.config/quickshell
QS_ALT_DIR = $(HOME_DIR)/.config/quickshell-alt

# Binaries to generate
TARGETS = theme.switcher sysmon_main sysmon_alt

all: $(TARGETS) wallpick

# 1. Compile Theme Switcher
theme.switcher: theme.switcher.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

# 2. Compile Wallpick (Only if the file exists)
wallpick:
	@if [ -f wallpick.cpp ]; then \
		$(CXX) $(CXXFLAGS) -o $@ wallpick.cpp; \
		echo "Compiled wallpick"; \
	fi

# 3. Compile standard sysmon daemon
sysmon_main: $(QS_DIR)/sysmon.cpp
	$(CXX) $(CXXFLAGS) -o $(QS_DIR)/sysmon $<

# 4. Compile floating pill sysmon daemon
sysmon_alt: $(QS_ALT_DIR)/sysmon.cpp
	$(CXX) $(CXXFLAGS) -o $(QS_ALT_DIR)/sysmon $<

# Clean compiled binaries
clean:
	rm -f theme.switcher wallpick
	rm -f $(QS_DIR)/sysmon $(QS_ALT_DIR)/sysmon

.PHONY: all clean wallpick
