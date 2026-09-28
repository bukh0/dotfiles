#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <thread>

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
            if (colon != std::string::npos) return trim(line.substr(colon + 1));
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
    std::string perfPath = homeDir ? std::string(homeDir) + "/.cache/perf-mode" : "";

    std::uint64_t lastIdle = 0, lastTotal = 0;
    std::uint64_t lastRx = 0, lastTx = 0;
    std::chrono::steady_clock::time_point lastTime = std::chrono::steady_clock::now();
    bool firstSample = true;

    std::ifstream statFile("/proc/stat");
    std::ifstream memFile("/proc/meminfo");
    std::ifstream netFile("/proc/net/dev");
    std::ifstream tempFile;
    if (tempPath != "none" && !tempPath.empty()) tempFile.open(tempPath.c_str());

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
            seededCpu = lastTotal > 0;
        }
    }
    if (!seededCpu) {
        std::cerr << "sysmon: failed to read /proc/stat" << std::endl;
        return 1;
    }

    while (true) {
        // 1. CPU
        statFile.clear(); statFile.seekg(0);
        unsigned long long idle = 0, total = 0;
        bool validCpu = false;
        if (std::getline(statFile, line)) {
            std::istringstream iss(line);
            std::string cpu;
            if (iss >> cpu && cpu == "cpu") {
                validCpu = true;
                unsigned long long val; int col = 1;
                while (iss >> val) {
                    if (col <= 8) total += val;
                    if (col == 4 || col == 5) idle += val;
                    col++;
                }
            }
        }
        if (!validCpu) {
            std::cerr << "sysmon: failed to read /proc/stat" << std::endl;
            return 1;
        }

        long cpuPct = 0;
        if (total > lastTotal) {
            auto dT = total - lastTotal;
            auto dI = (idle > lastIdle) ? (idle - lastIdle) : 0ULL;
            cpuPct = (dT > dI) ? (dT - dI) * 100 / dT : 0;
        }
        lastIdle = idle; lastTotal = total;
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
            std::cerr << "sysmon: failed to read /proc/meminfo" << std::endl;
            return 1;
        }
        long ramPct = memTotal > 0 ? (memTotal - memAvail) * 100 / memTotal : 0;
        std::string tooltipRam = "Total: " + std::to_string(memTotal / 1024) + " MB\\nAvailable: " + std::to_string(memAvail / 1024) +
                                 " MB\\nSwap: " + std::to_string((swapTotal - swapFree) / 1024) + " MB / " + std::to_string(swapTotal / 1024) + " MB";

        // 3. Network
        netFile.clear(); netFile.seekg(0);
        unsigned long long rxTotal = 0, txTotal = 0;
        if (!std::getline(netFile, line) || !std::getline(netFile, line)) {
            std::cerr << "sysmon: failed to read /proc/net/dev" << std::endl;
            return 1;
        }
        while (std::getline(netFile, line)) {
            size_t colon = line.find(':');
            if (colon != std::string::npos) {
                std::string iface = trim(line.substr(0, colon));
                if (!iface.empty() && iface != "lo" &&
                    iface.rfind("wg", 0) != 0 && iface.rfind("tun", 0) != 0 &&
                    (iface[0] == 'e' || iface[0] == 'w')) {
                    std::istringstream iss(line.substr(colon + 1));
                    unsigned long long rx = 0, tx = 0, dmy = 0;
                    if (iss >> rx) {
                        for (int i = 0; i < 7; ++i) iss >> dmy;
                        iss >> tx;
                        rxTotal += rx; txTotal += tx;
                    }
                }
            }
        }
        const std::chrono::steady_clock::time_point now = std::chrono::steady_clock::now();
        const double dt = std::chrono::duration<double>(now - lastTime).count();
        std::string rxSpeed = !firstSample && dt > 0
            ? formatSpeed((rxTotal > lastRx ? rxTotal - lastRx : 0) / dt)
            : "0 B/s";
        std::string txSpeed = !firstSample && dt > 0
            ? formatSpeed((txTotal > lastTx ? txTotal - lastTx : 0) / dt)
            : "0 B/s";
        lastRx = rxTotal; lastTx = txTotal; lastTime = now;
        firstSample = false;
        std::string tooltipNet = "↓ " + rxSpeed + "   ↑ " + txSpeed;

        // 4. Temp
        std::string tempStr = "N/A";
        std::string tooltipTemp = "Temperature: N/A";
        int isHot = 0;
        if (tempFile.is_open()) {
            tempFile.clear(); tempFile.seekg(0);
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
            if (!(pFile >> profile)) profile = "auto";
        }

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
