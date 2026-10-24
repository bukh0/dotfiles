CXX ?= g++
CXXFLAGS ?= -O3
PROJECT_CXXFLAGS = -std=c++17 -Wall -Wextra -Wpedantic
LDFLAGS ?=

.PHONY: all clean

all: sysmon

sysmon: sysmon.cpp
	$(CXX) $(PROJECT_CXXFLAGS) $(CXXFLAGS) $(LDFLAGS) -MMD -MP -MF sysmon.d -MT $@ -o $@ $<

clean:
	rm -f sysmon sysmon.d

-include sysmon.d
