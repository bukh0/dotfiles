# Compiler & Flags
CXX = g++
CXXFLAGS = -std=c++98 -O3 -Wall -Wextra -Werror

# Paths
HOME_DIR = $(HOME)
QS_DIR = $(HOME_DIR)/.config/quickshell
QS_SHARED_DIR = $(QS_DIR)/shared

# Binaries to generate
TARGETS = theme.switcher sysmon wallpick

all: $(TARGETS)

# 1. Compile Theme Switcher
theme.switcher: theme.switcher.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

# 2. Compile Wallpick (Only if the file exists)
wallpick: wallpick.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

# 3. Compile standard sysmon daemon
sysmon: $(QS_SHARED_DIR)/sysmon.cpp
	$(CXX) $(CXXFLAGS) -o $(QS_SHARED_DIR)/sysmon $<

# Clean compiled binaries
clean:
	rm -f theme.switcher wallpick
	rm -f $(QS_SHARED_DIR)/sysmon

.PHONY: all clean
