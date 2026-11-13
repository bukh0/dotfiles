CXX ?= c++
CXXFLAGS ?= -O2 -Wall -Wextra -Werror
PKGS = gtk+-3.0 jsoncpp

workspaces.so: workspaces.cpp
	$(CXX) $(CXXFLAGS) -std=c++17 -shared -fPIC -pthread $(shell pkg-config --cflags $(PKGS)) $< -o $@ $(shell pkg-config --libs $(PKGS))

.PHONY: check
check:
	$(CXX) $(CXXFLAGS) -std=c++17 -pthread $(shell pkg-config --cflags $(PKGS)) test_workspaces.cpp -o /tmp/waybar-test-workspaces $(shell pkg-config --libs $(PKGS)) -Wl,--wrap=socket,--wrap=connect,--wrap=setsockopt,--wrap=close,--wrap=send,--wrap=recv
	/tmp/waybar-test-workspaces
