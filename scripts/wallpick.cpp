#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>
#include <dirent.h>
#include <sys/stat.h>
#include <cstdlib>

std::string escapeShellArg(const std::string& arg) {
    std::string escaped = "'";
    for (size_t i = 0; i < arg.length(); ++i) {
        if (arg[i] == '\'') escaped += "'\\''";
        else escaped += arg[i];
    }
    escaped += "'";
    return escaped;
}

std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n");
    if (std::string::npos == first) return "";
    size_t last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, (last - first + 1));
}

bool hasImageExt(const std::string& name) {
    size_t dotPos = name.find_last_of('.');
    if (dotPos == std::string::npos) return false;
    std::string ext = name.substr(dotPos);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
    return (ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp" || ext == ".gif");
}

struct Wallpaper {
    std::string filename;
    time_t mtime;
    bool operator<(const Wallpaper& other) const { return mtime > other.mtime; }
};

int main() {
    // Dependency check (C++98 compliant array loop)
    const char* deps[] = {"rofi", "swww", "matugen", "notify-send"};
    for (size_t i = 0; i < sizeof(deps)/sizeof(deps[0]); ++i) {
        std::string check = std::string("command -v ") + deps[i] + " >/dev/null 2>&1";
        if (system(check.c_str()) != 0) {
            std::cerr << "Error: " << deps[i] << " is not installed." << std::endl;
            return 1;
        }
    }

    const char* homeDir = std::getenv("HOME");
    if (!homeDir) return 1;
    
    std::string wallRoot = std::string(homeDir) + "/Pictures/Wallpapers";
    std::string rofiTheme = std::string(homeDir) + "/.config/rofi/wallpaper.rasi";

    std::vector<Wallpaper> wallpapers;
    DIR* dir = opendir(wallRoot.c_str());
    if (dir != NULL) {
        struct dirent* ent;
        while ((ent = readdir(dir)) != NULL) {
            std::string name = ent->d_name;
            if (hasImageExt(name)) {
                std::string path = wallRoot + "/" + name;
                struct stat st;
                if (stat(path.c_str(), &st) == 0) {
                    Wallpaper w; w.filename = name; w.mtime = st.st_mtime;
                    wallpapers.push_back(w);
                }
            }
        }
        closedir(dir);
    }

    if (wallpapers.empty()) {
        system("notify-send 'Wallpaper' 'No images found'");
        return 0;
    }

    std::sort(wallpapers.begin(), wallpapers.end());

    std::ofstream wout("/tmp/wallpick_menu.txt");
    for (size_t i = 0; i < wallpapers.size(); ++i) {
        wout << wallpapers[i].filename << '\0' << "icon\x1f" << wallRoot << "/" << wallpapers[i].filename << '\n';
    }
    wout.close();

    std::string choiceFile = "/tmp/wallpick_choice.txt";
    
    // Optimization: Use native file redirection '<' instead of spawning a 'cat |' subshell pipeline
    std::string rofiCmd = "rofi -dmenu -i -show-icons -theme " + escapeShellArg(rofiTheme) + " -p '  Wallpaper' < /tmp/wallpick_menu.txt > " + choiceFile;
    system(rofiCmd.c_str());

    std::ifstream wf(choiceFile.c_str());
    std::string selectedWall;
    std::getline(wf, selectedWall);
    wf.close();
    
    selectedWall = trim(selectedWall);
    if (selectedWall.empty()) return 0;
    std::string fullPath = wallRoot + "/" + selectedWall;

    system(("swww img " + escapeShellArg(fullPath) + " --transition-type grow --transition-duration 2 --transition-fps 60 &").c_str());
    system(("matugen image " + escapeShellArg(fullPath) + " --source-color-index 0 -q").c_str());

    std::string baseName = selectedWall;
    size_t lastSlash = baseName.find_last_of('/');
    if (lastSlash != std::string::npos) baseName = baseName.substr(lastSlash + 1);

    system(("notify-send -a 'Wallpaper' 'Theme Updated' " + escapeShellArg(baseName) + " -i " + escapeShellArg(fullPath) + " -u low -t 2500").c_str());

    return 0;
}
