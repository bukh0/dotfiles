#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <memory>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <set>
#include <string>
#include <stdexcept>
#include <vector>
#include <fcntl.h>
#include <openssl/evp.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

namespace fs = std::filesystem;
std::string envPath(const char* key, const std::string& fallback) {
    const char* value = std::getenv(key);
    return value && *value ? value : fallback;
}
std::string quote(const std::string& value) {
    std::string out = "'";
    for (char c : value) out += c == '\'' ? "'\\''" : std::string(1, c);
    return out + "'";
}
bool run(const std::string& command) { return std::system(command.c_str()) == 0; }
struct Lock {
    int fd;
    explicit Lock(const fs::path& path) {
        fs::create_directories(path.parent_path());
        fd = open(path.c_str(), O_CREAT | O_RDWR | O_CLOEXEC, 0600);
        if (fd < 0) throw std::runtime_error("Cannot open lock: " + path.string());
        while (flock(fd, LOCK_EX) < 0) {
            if (errno == EINTR) continue;
            close(fd);
            throw std::runtime_error("Cannot acquire lock: " + path.string());
        }
    }
    ~Lock() { close(fd); }
    Lock(const Lock&) = delete;
};
struct Temp {
    fs::path path;
    explicit Temp(const std::string& pattern, int suffix = 0) {
        std::vector<char> value(pattern.begin(), pattern.end()); value.push_back(0);
        int fd = mkstemps(value.data(), suffix);
        if (fd < 0) throw std::runtime_error("Cannot create temporary file");
        close(fd); path = value.data();
    }
    ~Temp() { std::error_code ec; fs::remove(path, ec); }
    Temp(const Temp&) = delete;
};
fs::path destinationPath(fs::path path) {
    // Resolve the final symlink, including a relative/dangling target, before
    // creating a sibling temporary file. Parent symlinks are resolved too.
    for (int depth = 0; depth < 40; ++depth) {
        if (!fs::is_symlink(path)) return fs::weakly_canonical(path);
        auto target = fs::read_symlink(path);
        path = target.is_absolute() ? target : path.parent_path() / target;
    }
    throw std::runtime_error("Symlink loop: " + path.string());
}
bool atomicCopy(const fs::path& source, const fs::path& target) {
    try {
        auto dest = destinationPath(target);
        fs::create_directories(dest.parent_path());
        const auto mode = fs::exists(dest) ? fs::status(dest).permissions() : fs::status(source).permissions();
        Temp temp(dest.string() + ".tmp.XXXXXX");
        fs::copy_file(source, temp.path, fs::copy_options::overwrite_existing);
        fs::permissions(temp.path, mode);
        int fd = open(temp.path.c_str(), O_RDONLY | O_CLOEXEC);
        if (fd < 0) return false;
        int result = fsync(fd); close(fd);
        if (result != 0) return false;
        fs::rename(temp.path, dest);
        fd = open(dest.parent_path().c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (fd < 0) return false;
        result = fsync(fd); close(fd);
        return result == 0;
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n'; return false;
    }
}
std::string hash(const std::string& value) {
    unsigned char digest[EVP_MAX_MD_SIZE]; unsigned int count = 0;
    if (!EVP_Digest(value.data(), value.size(), digest, &count, EVP_sha256(), nullptr))
        throw std::runtime_error("Cannot hash thumbnail key");
    const char* digits = "0123456789abcdef"; std::string out;
    for (unsigned int i = 0; i < count; ++i) { out += digits[digest[i] >> 4]; out += digits[digest[i] & 15]; }
    return out;
}
bool imagePath(const fs::path& path) {
    auto ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return std::tolower(c); });
    return ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp";
}
struct Wallpaper {
    fs::path path;
    struct stat info;
    bool operator<(const Wallpaper& other) const {
        if (info.st_mtim.tv_sec != other.info.st_mtim.tv_sec) return info.st_mtim.tv_sec > other.info.st_mtim.tv_sec;
        if (info.st_mtim.tv_nsec != other.info.st_mtim.tv_nsec) return info.st_mtim.tv_nsec > other.info.st_mtim.tv_nsec;
        return path.filename() < other.path.filename();
    }
    fs::path thumb(const fs::path& cache) const {
        return cache / (hash(path.string() + '\0' + std::to_string(info.st_mtim.tv_sec) + ':' +
            std::to_string(info.st_mtim.tv_nsec) + ':' + std::to_string(info.st_size)) + ".jpg");
    }
};
std::vector<Wallpaper> scan(const fs::path& root) {
    std::vector<Wallpaper> walls;
    if (!fs::is_directory(root)) return walls;
    for (const auto& entry : fs::directory_iterator(root)) {
        if (!imagePath(entry.path())) continue;
        Wallpaper wall{entry.path(), {}};
        // The line/tab listing protocol cannot represent these filenames.
        if (wall.path.string().find_first_of("\n\r\t") != std::string::npos) continue;
        if (stat(wall.path.c_str(), &wall.info) == 0 && S_ISREG(wall.info.st_mode)) walls.push_back(wall);
    }
    std::sort(walls.begin(), walls.end()); return walls;
}
int thumbOne(const fs::path& source, const fs::path& dest) {
    Temp temp(dest.string() + ".part.XXXXXX.jpg", 4);
    // Explicit format: mkstemp's random suffix does not identify JPEG.
    const std::string output = temp.path.string() + "[Q=82,keep=none]";
    // --path performs % substitutions. Escape any percent in the cache root.
    std::string vipsOutput;
    for (char c : output) vipsOutput += c == '%' ? "%%" : std::string(1, c);
    bool ok = run("nice -n 10 vipsthumbnail --vips-concurrency=1 --size 400x --path " + quote(vipsOutput) + " -- " + quote(source.string()));
    if (!ok || fs::file_size(temp.path) == 0) return 1;
    fs::permissions(temp.path, fs::perms::owner_read | fs::perms::owner_write);
    fs::rename(temp.path, dest);
    // One write per record keeps output from parallel workers intact.
    const auto line = dest.string() + '\n';
    if (write(STDOUT_FILENO, line.data(), line.size()) < 0) return 1;
    return 0;
}
int thumbnails(const std::vector<Wallpaper>& walls, const fs::path& cache) {
    fs::create_directories(cache);
    Lock lock(cache.parent_path() / "thumbnails.lock");
    std::set<fs::path> wanted;
    Temp queue((cache / "queue.XXXXXX").string());
    std::ofstream out(queue.path, std::ios::binary);
    size_t missing = 0;
    for (const auto& wall : walls) {
        auto dest = wall.thumb(cache); wanted.insert(dest);
        if (fs::is_regular_file(dest) && fs::file_size(dest) > 0) continue;
        out << wall.path.string() << '\0' << dest.string() << '\0'; ++missing;
    }
    out.close();
    if (!out) throw std::runtime_error("Cannot write thumbnail queue");
    // Only this versioned, generated cache is pruned. The lock excludes workers
    // from another invocation, so abandoned partial files are safe to remove.
    for (const auto& entry : fs::directory_iterator(cache)) {
        if (entry.path() == queue.path || wanted.count(entry.path())) continue;
        if (entry.is_regular_file() || entry.is_symlink()) fs::remove(entry.path());
    }
    // Retire files produced by the historical slash-to-plus naming scheme.
    for (const auto& entry : fs::directory_iterator(cache.parent_path())) {
        const auto name = entry.path().filename().string();
        if (!name.empty() && name.front() == '+' && entry.is_regular_file() &&
            (entry.path().extension() == ".jpg" || (name.size() >= 9 && name.compare(name.size() - 9, 9, ".jpg.part") == 0)))
            fs::remove(entry.path());
    }
    if (!missing) return 0;
    const auto self = fs::read_symlink("/proc/self/exe").string();
    return run("xargs -0 -a " + quote(queue.path.string()) + " -n2 -P4 " + quote(self) + " --thumb-one") ? 0 : 1;
}
using Routes = std::vector<std::pair<fs::path, fs::path>>;
Routes routes(const fs::path& src, const fs::path& config, const std::string& theme) {
    Routes result;
    for (const auto& route : Routes{
        {"rofi.rasi", "rofi/colors.rasi"}, {"kitty.conf", "kitty/theme.conf"},
        {"waybar.css", "waybar/theme.css"}, {"gtk.css", "gtk-3.0/gtk.css"},
        {"swaync.css", "swaync/colors.css"}, {"hyprlock.conf", "hypr/hyprlock-colors.conf"},
        {"wlogout.css", "wlogout/colors.css"}, {"quickshell-colors.qml", "quickshell/components/Colors.qml"}}) {
        auto source = src / route.first;
        if (theme == "Matugen" && route.first == "gtk.css" && !fs::exists(source)) source = src / "gtk-3.css";
        result.emplace_back(source, config / route.second);
    }
    if (fs::is_regular_file(src / "midnight-discord.css"))
        result.emplace_back(src / "midnight-discord.css", config / "vesktop/themes/midnight-discord.css");
    return result;
}
bool install(const Routes& files) {
    for (const auto& pair : files) {
        if (!fs::is_regular_file(pair.first)) {
            std::cerr << "Missing theme output: " << pair.first << '\n'; return false;
        }
    }
    // Back up the entire destination set before committing any replacement.
    std::vector<std::unique_ptr<Temp>> backups;
    for (const auto& pair : files) {
        if (!fs::exists(pair.second)) { backups.push_back(nullptr); continue; }
        auto backup = std::make_unique<Temp>("/tmp/quickshell-theme-backup.XXXXXX");
        if (!atomicCopy(pair.second, backup->path)) return false;
        // Preserve the original mode in the rollback source too.
        fs::permissions(backup->path, fs::status(pair.second).permissions());
        backups.push_back(std::move(backup));
    }
    for (size_t i = 0; i < files.size(); ++i) {
        if (atomicCopy(files[i].first, files[i].second)) continue;
        std::cerr << "Could not install " << files[i].second << '\n';
        for (size_t j = 0; j <= i; ++j) {
            if (backups[j]) {
                if (!atomicCopy(backups[j]->path, files[j].second))
                    std::cerr << "Rollback failed: " << files[j].second << '\n';
            } else { std::error_code ec; fs::remove(destinationPath(files[j].second), ec); }
        }
        return false;
    }
    return true;
}
bool reload(const std::string& home) {
    run("pkill -USR1 -u " + std::to_string(getuid()) + " -x kitty 2>/dev/null || true");
    run("pkill -USR2 -u " + std::to_string(getuid()) + " -x waybar 2>/dev/null || true");
    run("pgrep -x swaync >/dev/null && swaync-client -rs >/dev/null 2>&1 &");
    if (run("bash -c 'source \"$1\" && quickshell_running' _ " + quote(home + "/.scripts/quickshell-common.sh")))
        return run(quote(home + "/.scripts/switch_quickshell.sh") + " reload");
    return true;
}
int main(int argc, char** argv) {
    try {
        const auto home = envPath("HOME", ""); if (home.empty()) return 1;
        const fs::path config = envPath("XDG_CONFIG_HOME", home + "/.config");
        const fs::path cacheRoot = envPath("XDG_CACHE_HOME", home + "/.cache");
        const auto cache = cacheRoot / "wall-thumbs/v2";
        const auto themes = config / "hypr/themes";
        const fs::path wallsRoot = home + "/Pictures/Wallpapers";
        const std::string flag = argc > 1 ? argv[1] : "";
        if (argc == 1) {
            execl((home + "/.scripts/picker-menu.sh").c_str(), "picker-menu.sh", nullptr);
            throw std::runtime_error("Cannot launch picker");
        }
        if (flag == "--thumb-one" && argc == 4) return thumbOne(argv[2], argv[3]);
        if (flag == "--list-walls" && argc == 2) {
            for (const auto& wall : scan(wallsRoot)) std::cout << wall.path.string() << '\t' << wall.thumb(cache).string() << '\n';
            return 0;
        }
        if (flag == "--thumbs" && argc == 2) return thumbnails(scan(wallsRoot), cache);
        std::vector<std::string> presets;
        if (fs::is_directory(themes)) for (const auto& entry : fs::directory_iterator(themes)) {
            auto name = entry.path().filename().string();
            if (entry.is_directory() && name != "matugen" && name != "pywal") presets.push_back(name);
        }
        std::sort(presets.begin(), presets.end());
        if (flag == "--list-themes" && argc == 2) {
            std::cout << "Matugen\npywal\n";
            for (const auto& name : presets) std::cout << name << '\n';
            return 0;
        }
        if (!(flag == "--apply" && (argc == 3 || argc == 4)) && !(flag == "--install-matugen" && argc == 2)) {
            std::cerr << "Usage: theme.switcher [--list-themes|--list-walls|--thumbs|--apply THEME [WALL]|--install-matugen]\n";
            return 2;
        }
        // All generation and installation entry points share this lock. Listing
        // and thumbnail generation remain independent and responsive.
        Lock lock(cacheRoot / "quickshell/theme-apply.lock");
        const std::string choice = flag == "--install-matugen" ? "Matugen" : argv[2];
        fs::path source;
        fs::path wall;
        if (choice != "Matugen" && choice != "pywal" && std::find(presets.begin(), presets.end(), choice) == presets.end())
            throw std::runtime_error("Unknown theme");
        if (flag == "--install-matugen") source = themes / "matugen/generated";
        else if (choice == "Matugen" || choice == "pywal") {
            if (argc != 4) throw std::runtime_error("A wallpaper is required");
            // Resolve the parent, but preserve a curated image symlink. The
            // listing accepts these links even when their targets live elsewhere.
            const auto requested = fs::absolute(argv[3]);
            wall = fs::canonical(requested.parent_path()) / requested.filename();
            auto relative = wall.lexically_relative(fs::canonical(wallsRoot));
            if (relative.empty() || *relative.begin() == ".." || !imagePath(wall) || !fs::is_regular_file(wall))
                throw std::runtime_error("Invalid wallpaper path");
            if (choice == "Matugen") {
                source = themes / "matugen/generated";
                if (!run("matugen image " + quote(wall.string()) + " -c " + quote((themes / "matugen/config.toml").string()) + " --prefer=saturation"))
                    throw std::runtime_error("Matugen theme generation failed");
            } else {
                source = cacheRoot / "wal";
                // Use the same small input on cold and warm caches. Hold the
                // thumbnail lock while wal reads it so pruning cannot race it.
                fs::create_directories(cache);
                Lock thumbLock(cache.parent_path() / "thumbnails.lock");
                Wallpaper selected{wall, {}};
                if (stat(wall.c_str(), &selected.info) != 0) throw std::runtime_error("Cannot read wallpaper metadata");
                const auto input = selected.thumb(cache);
                if ((!fs::is_regular_file(input) || fs::file_size(input) == 0) && thumbOne(wall, input) != 0)
                    throw std::runtime_error("Cannot prepare wallpaper for Pywal");
                if (!run("wal --backend colorthief -i " + quote(input.string()) + " -n -e -s -t -q"))
                    throw std::runtime_error("Pywal theme generation failed");
            }
        } else {
            source = themes / choice;
            auto images = scan(wallsRoot / choice);
            if (!images.empty()) wall = images[static_cast<size_t>(std::time(nullptr)) % images.size()].path;
        }
        if (!install(routes(source, config, choice))) return 1;
        // Wait for swww to accept the change; its daemon runs the transition.
        // Keep stderr and propagate failure instead of reporting false success.
        const bool wallpaperOk = wall.empty() || run("swww img " + quote(wall.string()) + " --transition-type center --transition-fps 60 --transition-duration 0.8 >/dev/null");
        const bool reloadOk = reload(home);
        if (!reloadOk)
            throw std::runtime_error(wallpaperOk
                ? "Theme colours were applied, but Quickshell could not reload. Check the bar log and try again."
                : "Theme colours were applied, but the wallpaper could not be set and Quickshell could not reload. Check swww and the bar log.");
        if (!wallpaperOk)
            throw std::runtime_error("Theme colours were applied, but the wallpaper could not be set. Check that swww is running and try again.");
        run("notify-send -a 'Theme Engine' -- " + quote("Theme updated to " + choice));
        return 0;
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
