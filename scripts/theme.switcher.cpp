#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>
#include <dirent.h>
#include <sys/stat.h>
#include <cstdlib>
#include <cstdio>
#include <ctime>

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

void replaceAll(std::string& str, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t start_pos = 0;
    while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length();
    }
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
    std::string fullPath;
    time_t mtime;
    bool operator<(const Wallpaper& other) const { return mtime > other.mtime; }
};

bool fileExists(const std::string& path) {
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0);
}

// Pure C++ atomic copy. No slow bash sub-shells.
bool atomicCopy(const std::string& src, const std::string& dest) {
    if (!fileExists(src)) return false;
    std::string tmp = dest + ".tmp";
    std::ifstream is(src.c_str(), std::ios::binary);
    std::ofstream os(tmp.c_str(), std::ios::binary);
    if (!is || !os) return false;
    os << is.rdbuf();
    is.close();
    os.close();
    return (std::rename(tmp.c_str(), dest.c_str()) == 0);
}

std::string getThumbPath(const std::string& thumbDir, const std::string& srcPath) {
    std::string safeName = srcPath;
    replaceAll(safeName, "/", "+");
    return thumbDir + "/" + safeName + ".jpg";
}

int main() {
    const char* homeDir = std::getenv("HOME");
    if (!homeDir) return 1;
    std::string home(homeDir);

    std::string themeDir = home + "/.config/hypr/themes";
    std::string wallRoot = home + "/Pictures/Wallpapers";
    std::string thumbDir = home + "/.cache/wall-thumbs";
    std::string rofiConf = home + "/.config/rofi/config.rasi";
    std::string rofiWall = home + "/.config/rofi/wallpaper.rasi";

    system(("mkdir -p " + escapeShellArg(thumbDir) + " " + escapeShellArg(home + "/.config/vesktop/themes")).c_str());

    std::vector<std::string> presets;
    DIR* dir = opendir(themeDir.c_str());
    if (dir != NULL) {
        struct dirent* ent;
        while ((ent = readdir(dir)) != NULL) {
            std::string name = ent->d_name;
            if (name == "." || name == ".." || name == "matugen" || name == "pywal") continue;
            struct stat st;
            if (stat((themeDir + "/" + name).c_str(), &st) == 0 && S_ISDIR(st.st_mode)) {
                presets.push_back(name);
            }
        }
        closedir(dir);
    }
    
    std::sort(presets.begin(), presets.end());
    
    std::string menu = "Matugen\npywal";
    for (size_t i = 0; i < presets.size(); ++i) menu += "\n" + presets[i];
    
    std::ofstream mout("/tmp/theme_menu.txt");
    mout << menu;
    mout.close();

    std::string choiceFile = "/tmp/theme_choice.txt";
    system(("cat /tmp/theme_menu.txt | rofi -dmenu -i -p '󰃟 Theme' -config " + escapeShellArg(rofiConf) + " > " + choiceFile).c_str());

    std::ifstream cf(choiceFile.c_str());
    std::string choice;
    std::getline(cf, choice);
    cf.close();
    
    choice = trim(choice);
    if (choice.empty()) return 0;

    std::string fullPath = "";
    std::string srcDir = "";

    if (choice == "Matugen" || choice == "pywal") {
        std::vector<Wallpaper> wallpapers;
        dir = opendir(wallRoot.c_str());
        if (dir != NULL) {
            struct dirent* ent;
            while ((ent = readdir(dir)) != NULL) {
                std::string name = ent->d_name;
                if (hasImageExt(name)) {
                    std::string path = wallRoot + "/" + name;
                    struct stat st;
                    if (stat(path.c_str(), &st) == 0) {
                        Wallpaper w; w.filename = name; w.fullPath = path; w.mtime = st.st_mtime;
                        wallpapers.push_back(w);
                    }
                }
            }
            closedir(dir);
        }

        if (wallpapers.empty()) {
            system(("notify-send -a 'Theme Engine' 'No wallpapers in " + escapeShellArg(wallRoot) + "'").c_str());
            return 1;
        }

        std::sort(wallpapers.begin(), wallpapers.end());

        std::string thumbQueue = "";
        for (size_t i = 0; i < wallpapers.size(); ++i) {
            std::string thumb = getThumbPath(thumbDir, wallpapers[i].fullPath);
            struct stat stThumb, stSrc;
            if (!(stat(thumb.c_str(), &stThumb) == 0 && stat(wallpapers[i].fullPath.c_str(), &stSrc) == 0 && stThumb.st_mtime >= stSrc.st_mtime)) {
                thumbQueue += escapeShellArg(wallpapers[i].fullPath) + " ";
            }
        }

        if (!thumbQueue.empty()) {
            std::string mkThumbCmd = "printf '%s\\0' " + thumbQueue + " | xargs -0 -n1 -P\"$(nproc)\" bash -c 'REPLY=\"" + thumbDir + "/${1//\\//+}.jpg\"; magick -limit thread 1 -define jpeg:size=1280x720 \"$1[0]\" -thumbnail 640x -strip -quality 85 \"jpg:$REPLY.part\" 2>/dev/null && mv -f \"$REPLY.part\" \"$REPLY\"' _";
            system(mkThumbCmd.c_str());
        }

        std::ofstream wout("/tmp/wall_menu.txt");
        for (size_t i = 0; i < wallpapers.size(); ++i) {
            wout << wallpapers[i].filename << '\0' << "icon\x1f" << getThumbPath(thumbDir, wallpapers[i].fullPath) << '\n';
        }
        wout.close();

        std::string wallChoiceFile = "/tmp/wall_choice.txt";
        system(("cat /tmp/wall_menu.txt | rofi -dmenu -i -show-icons -theme " + escapeShellArg(rofiWall) + " -p ' Wallpaper' > " + wallChoiceFile).c_str());

        std::ifstream wf(wallChoiceFile.c_str());
        std::string selectedWall;
        std::getline(wf, selectedWall);
        wf.close();
        
        selectedWall = trim(selectedWall);
        if (selectedWall.empty()) return 0;
        fullPath = wallRoot + "/" + selectedWall;
        
    } else {
        std::vector<std::string> presetImgs;
        std::string presetDir = wallRoot + "/" + choice;
        dir = opendir(presetDir.c_str());
        if (dir != NULL) {
            struct dirent* ent;
            while ((ent = readdir(dir)) != NULL) {
                std::string name = ent->d_name;
                if (hasImageExt(name)) presetImgs.push_back(presetDir + "/" + name);
            }
            closedir(dir);
        }
        if (!presetImgs.empty()) {
            std::srand(std::time(0));
            fullPath = presetImgs[std::rand() % presetImgs.size()];
        }
    }

    if (!fullPath.empty() && fileExists(fullPath)) {
        system(("swww img " + escapeShellArg(fullPath) + " --transition-type center --transition-fps 60 --transition-duration 0.8 &>/dev/null &").c_str());
    }

    if (choice == "Matugen") {
        srcDir = themeDir + "/matugen/generated";
        system(("matugen image " + escapeShellArg(fullPath) + " -c " + escapeShellArg(themeDir + "/matugen/config.toml") + " --prefer=saturation").c_str());
    } else if (choice == "pywal") {
        srcDir = home + "/.cache/wal";
        std::string thumbTarget = fileExists(getThumbPath(thumbDir, fullPath)) ? getThumbPath(thumbDir, fullPath) : fullPath;
        system(("wal --backend colorthief -i " + escapeShellArg(thumbTarget) + " -n -e -s -t -q").c_str());
    } else {
        srcDir = themeDir + "/" + choice;
    }

    std::vector<std::pair<std::string, std::string> > routes;
    routes.push_back(std::make_pair("rofi.rasi", home + "/.config/rofi/colors.rasi"));
    routes.push_back(std::make_pair("kitty.conf", home + "/.config/kitty/theme.conf"));
    routes.push_back(std::make_pair("waybar.css", home + "/.config/waybar/theme.css"));
    routes.push_back(std::make_pair("gtk.css", home + "/.config/gtk-3.0/gtk.css"));
    routes.push_back(std::make_pair("swaync.css", home + "/.config/swaync/colors.css"));
    routes.push_back(std::make_pair("hyprlock.conf", home + "/.config/hypr/hyprlock-colors.conf"));
    routes.push_back(std::make_pair("wlogout.css", home + "/.config/wlogout/colors.css"));
    routes.push_back(std::make_pair("midnight-discord.css", home + "/.config/vesktop/themes/midnight-discord.css"));
    routes.push_back(std::make_pair("quickshell-colors.qml", home + "/.config/quickshell/Colors.qml"));
    routes.push_back(std::make_pair("quickshell-colors.qml", home + "/.config/quickshell-alt/Colors.qml"));

    for (size_t i = 0; i < routes.size(); ++i) {
        atomicCopy(srcDir + "/" + routes[i].first, routes[i].second);
    }

    system("pkill -USR1 -x kitty");
    system("pkill -USR2 -x waybar");
    system("pkill -0 swaync && swaync-client -rs &>/dev/null &");
    system("~/.scripts/switch_quickshell.sh reload &");

    std::string notifyCmd = "notify-send -a 'Theme Engine' " + escapeShellArg("Theme updated to " + choice);
    if (!fullPath.empty()) {
        std::string thumb = getThumbPath(thumbDir, fullPath);
        if (fileExists(thumb)) notifyCmd += " -i " + escapeShellArg(thumb);
        else notifyCmd += " -i " + escapeShellArg(fullPath);
    }
    system(notifyCmd.c_str());

    return 0;
}
