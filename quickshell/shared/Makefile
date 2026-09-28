CXX ?= g++
CXXFLAGS ?= -std=c++17 -O3 -Wall -Wextra -Wpedantic
LDFLAGS ?=

.PHONY: all clean

all: sysmon

sysmon: sysmon.cpp
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -MMD -MP -MF sysmon.d -MT $@ -o $@ $<

clean:
	rm -f sysmon sysmon.d

-include sysmon.d
