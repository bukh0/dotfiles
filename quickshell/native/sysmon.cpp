#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <thread>
#include <unordered_map>

std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n");
    if (std::string::npos == first) return "";
    size_t last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, (last - first + 1));
}

std::string getCpuModel() {
    std::ifstream file("/proc/cpuinfo");
    std::string line;
    while (std::getline(file, line)) {
        if (line.find("model name") == 0) {
            size_t colon = line.find(':');
            if (colon != std::string::npos) {
                std::string model = trim(line.substr(colon + 1));
                for (char& ch : model)
                    if (ch == '\x1f' || ch == '\r' || ch == '\n') ch = ' ';
                return model;
            }
        }
    }
    return "Unknown CPU";
}

std::string formatSpeed(double bytesPerSec) {
    std::ostringstream oss;
    oss.precision(1);
    oss << std::fixed;
    if (bytesPerSec < 1024) oss << (int)bytesPerSec << " B/s";
    else if (bytesPerSec < 1048576) oss << (bytesPerSec / 1024.0) << " K/s";
    else oss << (bytesPerSec / 1048576.0) << " M/s";
    return oss.str();
}

int main(int argc, char* argv[]) {
    std::string tempPath = (argc > 1) ? argv[1] : "";
    std::string cpuModel = getCpuModel();
    const char* homeDir = std::getenv("HOME");
    const char* cacheDir = std::getenv("XDG_CACHE_HOME");
    std::string perfPath = cacheDir && *cacheDir ? std::string(cacheDir) + "/perf-mode"
        : homeDir ? std::string(homeDir) + "/.cache/perf-mode" : "";

    std::uint64_t lastIdle = 0, lastTotal = 0;
    struct Counters { std::uint64_t rx, tx; };
    std::unordered_map<std::string, Counters> previousInterfaces;
    std::chrono::steady_clock::time_point lastTime = std::chrono::steady_clock::now();
    bool firstSample = true;

    std::ifstream statFile("/proc/stat");
    std::ifstream memFile("/proc/meminfo");
    std::ifstream netFile("/proc/net/dev");

    std::string line;

    if (!statFile.is_open() || !memFile.is_open() || !netFile.is_open()) {
        std::cerr << "sysmon: required /proc file unavailable" << std::endl;
        return 1;
    }

    bool seededCpu = false;
    if (std::getline(statFile, line)) {
        std::istringstream iss(line);
        std::string cpu;
        if (iss >> cpu && cpu == "cpu") {
            std::uint64_t val; int col = 1;
            while (iss >> val) {
                if (col <= 8) lastTotal += val;
                if (col == 4 || col == 5) lastIdle += val;
                col++;
            }
            seededCpu = col > 4 && iss.eof() && lastTotal > 0;
        }
    }
    if (!seededCpu) {
        std::cerr << "sysmon: failed to read /proc/stat" << std::endl;
        return 1;
    }

    bool sampleErrorLogged = false;
    const auto skipSample = [&](const char* path) {
        if (!sampleErrorLogged)
            std::cerr << "sysmon: failed to read " << path << "; retrying" << std::endl;
        sampleErrorLogged = true;
        // A persistent error must not spin or flood the collector with logs.
        std::this_thread::sleep_for(std::chrono::seconds(1));
    };

    while (std::cout.good()) {
        // 1. CPU
        statFile.clear(); statFile.seekg(0);
        unsigned long long idle = 0, total = 0;
        bool validCpu = false;
        if (std::getline(statFile, line)) {
            std::istringstream iss(line);
            std::string cpu;
            if (iss >> cpu && cpu == "cpu") {
                unsigned long long val; int col = 1;
                while (iss >> val) {
                    if (col <= 8) total += val;
                    if (col == 4 || col == 5) idle += val;
                    col++;
                }
                validCpu = col > 4 && iss.eof();
            }
        }
        if (!validCpu) {
            skipSample("/proc/stat");
            continue;
        }

        long cpuPct = 0;
        if (total > lastTotal) {
            auto dT = total - lastTotal;
            auto dI = (idle > lastIdle) ? (idle - lastIdle) : 0ULL;
            cpuPct = (dT > dI) ? ((dT - dI) * 100 + dT / 2) / dT : 0;
        }
        std::string tooltipCpu = "CPU: " + std::to_string(cpuPct) + "%\\n" + cpuModel;

        // 2. RAM
        memFile.clear(); memFile.seekg(0);
        unsigned long long memTotal = 0, memAvail = 0, swapTotal = 0, swapFree = 0;
        int found = 0;  // bitmask of keys seen, so zero values (no swap) still end the scan
        while (std::getline(memFile, line)) {
            std::istringstream iss(line);
            std::string key; unsigned long long val;
            if (iss >> key >> val) {
                if (key == "MemTotal:") { memTotal = val; found |= 1; }
                else if (key == "MemAvailable:") { memAvail = val; found |= 2; }
                else if (key == "SwapTotal:") { swapTotal = val; found |= 4; }
                else if (key == "SwapFree:") { swapFree = val; found |= 8; }
                if (found == 15) break;
            }
        }
        if (found != 15 || memTotal == 0 || memAvail > memTotal || swapFree > swapTotal) {
            skipSample("/proc/meminfo");
            continue;
        }
        long ramPct = memTotal > 0 ? ((memTotal - memAvail) * 100 + memTotal / 2) / memTotal : 0;
        std::string tooltipRam = "Total: " + std::to_string(memTotal / 1024) + " MB\\nAvailable: " + std::to_string(memAvail / 1024) +
                                 " MB\\nSwap: " + std::to_string((swapTotal - swapFree) / 1024) + " MB / " + std::to_string(swapTotal / 1024) + " MB";

        // 3. Network
        netFile.clear(); netFile.seekg(0);
        std::uint64_t rxDelta = 0, txDelta = 0;
        std::unordered_map<std::string, Counters> interfaces;
        if (!std::getline(netFile, line) || !std::getline(netFile, line)) {
            skipSample("/proc/net/dev");
            continue;
        }
        while (std::getline(netFile, line)) {
            size_t colon = line.find(':');
            if (colon != std::string::npos) {
                std::string iface = trim(line.substr(0, colon));
                if (!iface.empty() && iface != "lo" &&
                    iface.rfind("wg", 0) != 0 && iface.rfind("tun", 0) != 0 &&
                    (iface[0] == 'e' || iface[0] == 'w' || iface.rfind("usb", 0) == 0 ||
                     iface.rfind("bnep", 0) == 0 || iface.rfind("ppp", 0) == 0)) {
                    std::istringstream iss(line.substr(colon + 1));
                    unsigned long long rx = 0, tx = 0, dmy = 0;
                    if (iss >> rx) {
                        for (int i = 0; i < 7; ++i) iss >> dmy;
                        if (!(iss >> tx)) continue;
                        interfaces[iface] = {rx, tx};
                        const auto previous = previousInterfaces.find(iface);
                        if (previous != previousInterfaces.end()) {
                            // New/reset interfaces establish a baseline; neither
                            // should erase traffic from surviving interfaces.
                            if (rx >= previous->second.rx) rxDelta += rx - previous->second.rx;
                            if (tx >= previous->second.tx) txDelta += tx - previous->second.tx;
                        }
                    }
                }
            }
        }
        const std::chrono::steady_clock::time_point now = std::chrono::steady_clock::now();
        const double dt = std::chrono::duration<double>(now - lastTime).count();
        std::string rxSpeed = !firstSample && dt > 0
            ? formatSpeed(rxDelta / dt)
            : "0 B/s";
        std::string txSpeed = !firstSample && dt > 0
            ? formatSpeed(txDelta / dt)
            : "0 B/s";
        // Commit baselines together only after every required input is valid.
        // The next valid row then averages CPU/network over the skipped interval.
        lastIdle = idle;
        lastTotal = total;
        previousInterfaces = std::move(interfaces);
        lastTime = now;
        firstSample = false;
        std::string tooltipNet = "↓ " + rxSpeed + "   ↑ " + txSpeed;

        // 4. Temp
        std::string tempStr = "N/A";
        std::string tooltipTemp = "Temperature: N/A";
        int isHot = 0;
        // Reopen each sample so replaced/rebound sysfs nodes can recover.
        if (tempPath != "none" && !tempPath.empty()) {
            std::ifstream tempFile(tempPath);
            long tempRaw = 0;
            if (tempFile >> tempRaw) {
                long tempC = tempRaw / 1000;
                tempStr = std::to_string(tempC) + "°C";
                isHot = (tempC > 75) ? 1 : 0;
                tooltipTemp = "Temperature: " + tempStr + (isHot ? "\\n⚠ Above 75°C" : "");
            }
        }

        // 5. Power profile
        std::string profile = "auto";
        if (!perfPath.empty()) {
            std::ifstream pFile(perfPath.c_str());
            // Match the toggle script's first-line state, including files
            // without a trailing newline. Never publish arbitrary cache text.
            std::string state;
            std::getline(pFile, state);
            state = trim(state);
            if (state == "auto" || state == "powersave" || state == "performance")
                profile = state;
        }

        sampleErrorLogged = false;
        const char delimiter = '\x1f';
        std::cout << ramPct << "%" << delimiter << tooltipRam << delimiter
                  << cpuPct << "%" << delimiter << tooltipCpu << delimiter
                  << rxSpeed << delimiter << txSpeed << delimiter << tooltipNet << delimiter
                  << tempStr << delimiter << isHot << delimiter << tooltipTemp << delimiter
                  << profile << std::endl;

        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    return 0;
}
