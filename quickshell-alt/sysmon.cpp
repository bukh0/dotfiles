#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <cstdlib>
#include <unistd.h>
#include <sys/time.h>

std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n");
    if (std::string::npos == first) return str;
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
    else if (bytesPerSec < 1048576) oss << (int)(bytesPerSec / 1024) << " K/s";
    else oss << (bytesPerSec / 1048576) << " M/s";
    return oss.str();
}

template <typename T>
std::string toStr(T val) {
    std::ostringstream oss;
    oss << val;
    return oss.str();
}

int main(int argc, char* argv[]) {
    std::string tempPath = (argc > 1) ? argv[1] : "";
    std::string cpuModel = getCpuModel();
    const char* homeDir = std::getenv("HOME");
    std::string perfPath = homeDir ? std::string(homeDir) + "/.cache/perf-mode" : "";

    unsigned long lastIdle = 0, lastTotal = 0;
    unsigned long lastRx = 0, lastTx = 0;
    struct timeval lastTime;
    gettimeofday(&lastTime, NULL);

    // Keep file streams open for zero-overhead polling
    std::ifstream statFile("/proc/stat");
    std::ifstream memFile("/proc/meminfo");
    std::ifstream netFile("/proc/net/dev");
    std::ifstream tempFile;
    if (tempPath != "none" && !tempPath.empty()) tempFile.open(tempPath.c_str());

    std::string line;

    // Seed CPU deltas so the first real reading is instantaneous,
    // not "usage since boot".
    if (std::getline(statFile, line)) {
        std::istringstream iss(line);
        std::string cpu;
        if (iss >> cpu && cpu == "cpu") {
            unsigned long val; int col = 1;
            while (iss >> val) {
                lastTotal += val;
                if (col == 4) lastIdle = val;
                col++;
            }
        }
    }

    while (true) {
        usleep(3000000);

        // 1. CPU
        statFile.clear(); statFile.seekg(0);
        unsigned long idle = 0, total = 0;
        if (std::getline(statFile, line)) {
            std::istringstream iss(line);
            std::string cpu;
            if (iss >> cpu && cpu == "cpu") {
                unsigned long val; int col = 1;
                while (iss >> val) {
                    total += val;
                    if (col == 4) idle = val;
                    col++;
                }
            }
        }
        long cpuPct = 0;
        if (total > lastTotal) {
            cpuPct = ((total - lastTotal) - (idle - lastIdle)) * 100 / (total - lastTotal);
        }
        lastIdle = idle; lastTotal = total;
        std::string tooltipCpu = "CPU: " + toStr(cpuPct) + "%\\n" + cpuModel;

        // 2. RAM
        memFile.clear(); memFile.seekg(0);
        unsigned long memTotal = 0, memAvail = 0, swapTotal = 0, swapFree = 0;
        while (std::getline(memFile, line)) {
            std::istringstream iss(line);
            std::string key; unsigned long val;
            if (iss >> key >> val) {
                if (key == "MemTotal:") memTotal = val;
                else if (key == "MemAvailable:") memAvail = val;
                else if (key == "SwapTotal:") swapTotal = val;
                else if (key == "SwapFree:") swapFree = val;
            }
        }
        long ramPct = memTotal > 0 ? (memTotal - memAvail) * 100 / memTotal : 0;
        std::string tooltipRam = "Total: " + toStr(memTotal / 1024) + " MB\\nAvailable: " + toStr(memAvail / 1024) +
                                 " MB\\nSwap: " + toStr((swapTotal - swapFree) / 1024) + " MB / " + toStr(swapTotal / 1024) + " MB";

        // 3. Network
        netFile.clear(); netFile.seekg(0);
        unsigned long rxTotal = 0, txTotal = 0;
        std::getline(netFile, line); std::getline(netFile, line);
        while (std::getline(netFile, line)) {
            size_t colon = line.find(':');
            if (colon != std::string::npos) {
                std::string iface = trim(line.substr(0, colon));
                if (!iface.empty() && iface != "lo" && (iface[0] == 'e' || iface[0] == 'w')) {
                    std::istringstream iss(line.substr(colon + 1));
                    unsigned long rx, tx, dmy;
                    if (iss >> rx) {
                        for (int i = 0; i < 7; ++i) iss >> dmy;
                        iss >> tx;
                        rxTotal += rx; txTotal += tx;
                    }
                }
            }
        }
        struct timeval now;
        gettimeofday(&now, NULL);
        double dt = (now.tv_sec - lastTime.tv_sec) + (now.tv_usec - lastTime.tv_usec) / 1000000.0;
        std::string rxSpeed = dt > 0 ? formatSpeed((rxTotal > lastRx ? rxTotal - lastRx : 0) / dt) : "0 B/s";
        std::string txSpeed = dt > 0 ? formatSpeed((txTotal > lastTx ? txTotal - lastTx : 0) / dt) : "0 B/s";
        lastRx = rxTotal; lastTx = txTotal; lastTime = now;
        std::string tooltipNet = "↓ " + rxSpeed + "    ↑ " + txSpeed;

        // 4. Temp
        std::string tempStr = "N/A";
        std::string tooltipTemp = "Temperature: N/A";
        int isHot = 0;
        if (tempFile.is_open()) {
            tempFile.clear(); tempFile.seekg(0);
            long tempRaw = 0;
            if (tempFile >> tempRaw) {
                long tempC = tempRaw / 1000;
                tempStr = toStr(tempC) + "°C";
                isHot = (tempC > 75) ? 1 : 0;
                tooltipTemp = "Temperature: " + tempStr + (isHot ? "\\n⚠ Above 75°C" : "");
            }
        }

        // 5. Power profile — file gets overwritten by other scripts, must reopen each time
        std::string profile = "auto";
        if (!perfPath.empty()) {
            std::ifstream pFile(perfPath.c_str());
            if (!(pFile >> profile)) profile = "auto";
        }

        std::cout << ramPct << "%|" << tooltipRam << "|"
                  << cpuPct << "%|" << tooltipCpu << "|"
                  << rxSpeed << "|" << txSpeed << "|" << tooltipNet << "|"
                  << tempStr << "|" << isHot << "|" << tooltipTemp << "|"
                  << profile << std::endl;
    }
    return 0;
}
