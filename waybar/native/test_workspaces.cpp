#include "workspaces.cpp"
#include <cassert>
#include <vector>

static std::vector<std::string> commands;
static bool legacyOnly = false;
static std::string pending;
extern "C" int __wrap_socket(int, int, int) { return 12345; }
extern "C" int __wrap_connect(int, const sockaddr*, socklen_t) { return 0; }
extern "C" int __wrap_setsockopt(int, int, int, const void*, socklen_t) { return 0; }
extern "C" int __wrap_close(int) { return 0; }
extern "C" ssize_t __wrap_send(int, const void* buffer, size_t size, int) {
    commands.emplace_back(static_cast<const char*>(buffer), size);
    pending = legacyOnly && commands.back().find("hl.dsp.focus") != std::string::npos ? "Invalid dispatcher" : "ok";
    return size;
}
extern "C" ssize_t __wrap_recv(int, void* buffer, size_t size, int) {
    auto count = std::min(size, pending.size());
    memcpy(buffer, pending.data(), count);
    pending.erase(0, count);
    return count;
}
int main() {
    setenv("XDG_RUNTIME_DIR", "/tmp", 1);
    setenv("HYPRLAND_INSTANCE_SIGNATURE", "test", 1);
    focus("2");
    assert(commands.size() == 1);
    assert(commands.back() == "dispatch hl.dsp.focus({ workspace = \"2\" })");
    focus("name:research \"notes\"");
    assert(commands.back() == "dispatch hl.dsp.focus({ workspace = \"name:research \\\"notes\\\"\" })");
    legacyOnly = true;
    focus("3");
    assert(commands.size() == 4 && commands.back() == "dispatch workspace 3");
    auto spaces = parse(R"([{"id":2,"name":"2","windows":1},{"id":7,"name":"7","windows":0}])");
    auto monitors = parse(R"([{"id":0,"name":"eDP-1","activeWorkspace":{"id":2}},{"id":1,"name":"DP-1","activeWorkspace":{"id":7}}])");
    auto list = collect(spaces, monitors, 2, parse(R"({"*":[1,2,3]})"));
    assert(list.size() == 4 && list[2].active && !list[2].empty);
    assert(list[7].visible && !list[7].active && list[7].empty);
    assert(list[1].persistent && list[1].empty);
    list = collect(spaces, monitors, 7, parse(R"({"*":5})"));
    assert(list.size() == 10 && list[7].active && !list[2].active);
    assert(parse("not JSON").isNull());
    puts("PASS: Lua workspace selection, safe names, legacy fallback, persistent workspaces, multi-monitor active states");
}
