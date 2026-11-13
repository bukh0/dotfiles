// Waybar CFFI v2 workspace buttons for Hyprland's Lua dispatcher.
#include <gtk/gtk.h>
#include <json/json.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <unistd.h>
#include <atomic>
#include <cstring>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>

extern "C" {
struct wbcffi_module;
struct Init {
    wbcffi_module* obj;
    const char* version;
    GtkContainer* (*root)(wbcffi_module*);
    void (*update)(wbcffi_module*);
};
struct Entry { const char* key; const char* value; };
extern const size_t wbcffi_version = 2;
}

static Json::Value parse(const std::string& text) {
    Json::Value value;
    Json::CharReaderBuilder reader;
    std::string error;
    std::istringstream stream(text);
    if (!Json::parseFromStream(reader, stream, &value, &error)) return {};
    return value;
}
static std::string quote(const std::string& text) {
    Json::StreamWriterBuilder writer;
    writer["indentation"] = "";
    return Json::writeString(writer, Json::Value(text));
}
static std::string socketPath(const char* name) {
    const char* runtime = getenv("XDG_RUNTIME_DIR");
    const char* signature = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!runtime || !signature) return {};
    return std::string(runtime) + "/hypr/" + signature + "/" + name;
}
static int connectSocket(const char* name) {
    auto path = socketPath(name);
    sockaddr_un address{};
    address.sun_family = AF_UNIX;
    if (path.empty() || path.size() >= sizeof(address.sun_path)) return -1;
    memcpy(address.sun_path, path.c_str(), path.size() + 1);
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;
    timeval timeout{1, 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    if (connect(fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}
static std::string request(const std::string& command) {
    int fd = connectSocket(".socket.sock");
    if (fd < 0) return {};
    size_t sent = 0;
    while (sent < command.size()) {
        auto n = send(fd, command.data() + sent, command.size() - sent, MSG_NOSIGNAL);
        if (n <= 0) { close(fd); return {}; }
        sent += n;
    }
    std::string reply;
    char buffer[8192];
    ssize_t n;
    while ((n = recv(fd, buffer, sizeof(buffer), 0)) > 0) reply.append(buffer, n);
    close(fd);
    return reply;
}
static bool success(const std::string& reply) { return reply == "ok" || reply == "ok\n"; }
static void focus(const std::string& selector) {
    // Lua dispatch takes an action expression; JSON quotes safely encode workspace names.
    auto reply = request("dispatch hl.dsp.focus({ workspace = " + quote(selector) + " })");
    if (!success(reply)) {
        auto legacy = request("dispatch workspace " + selector);
        if (!success(legacy)) g_warning("Waybar workspace switch failed: %s / %s", reply.c_str(), legacy.c_str());
    }
}
struct Workspace { int id; std::string name; bool active{}, visible{}, persistent{}, empty{}, urgent{}; };
static std::map<int, Workspace> collect(const Json::Value& spaces, const Json::Value& monitors,
                                        int active, const Json::Value& persistent) {
    std::map<int, Workspace> result;
    auto addPersistent = [&](int id) {
        if (id > 0) result.emplace(id, Workspace{id, std::to_string(id), false, false, true, true});
    };
    for (const auto& key : persistent.getMemberNames()) {
        const auto& value = persistent[key];
        if (value.isArray()) {
            for (const auto& id : value) if (id.isInt()) addPersistent(id.asInt());
        } else if (value.isInt()) {
            for (const auto& monitor : monitors) {
                if (key != "*" && key != monitor["name"].asString()) continue;
                for (int i = 1; i <= value.asInt(); ++i) addPersistent(monitor["id"].asInt() * value.asInt() + i);
            }
        }
    }
    for (const auto& space : spaces) {
        int id = space["id"].asInt();
        if (id <= 0) continue; // These presets don't display special workspaces.
        bool fixed = result.count(id);
        result[id] = {id, space["name"].asString(), id == active, false, fixed,
                      space["windows"].asInt() == 0, space.get("urgent", false).asBool()};
    }
    for (const auto& monitor : monitors) {
        auto id = monitor["activeWorkspace"]["id"].asInt();
        if (result.count(id)) result[id].visible = true;
    }
    for (auto& [id, space] : result) space.active = id == active;
    return result;
}
struct Module {
    Init api;
    Json::Value config;
    GtkWidget* box;
    std::map<int, GtkWidget*> buttons;
    std::mutex mutex;
    std::map<int, Workspace> snapshot;
    std::atomic<bool> running{true};
    std::thread worker;
};
static void replace(std::string& text, const std::string& key, const std::string& value) {
    size_t pos = 0;
    while ((pos = text.find(key, pos)) != std::string::npos) {
        text.replace(pos, key.size(), value);
        pos += value.size();
    }
}
static void render(Module* module) {
    std::map<int, Workspace> spaces;
    { std::lock_guard lock(module->mutex); spaces = module->snapshot; }
    for (auto it = module->buttons.begin(); it != module->buttons.end();) {
        if (!spaces.count(it->first)) { gtk_widget_destroy(it->second); it = module->buttons.erase(it); }
        else ++it;
    }
    int position = 0;
    for (const auto& [id, space] : spaces) {
        GtkWidget* button;
        if (!module->buttons.count(id)) {
            button = gtk_button_new();
            gtk_button_set_relief(GTK_BUTTON(button), GTK_RELIEF_NONE);
            g_signal_connect(button, "clicked", G_CALLBACK(+[](GtkButton* clicked, gpointer) {
                focus(static_cast<const char*>(g_object_get_data(G_OBJECT(clicked), "workspace-selector")));
            }), nullptr);
            gtk_box_pack_start(GTK_BOX(module->box), button, false, false, 0);
            module->buttons[id] = button;
        } else button = module->buttons[id];
        std::string selector = space.id > 0 ? std::to_string(space.id) : "name:" + space.name;
        g_object_set_data_full(G_OBJECT(button), "workspace-selector", g_strdup(selector.c_str()), g_free);
        auto* context = gtk_widget_get_style_context(button);
        for (auto [name, enabled] : {std::pair{"active", space.active}, {"visible", space.visible},
                                    {"persistent", space.persistent}, {"empty", space.empty}, {"urgent", space.urgent}}) {
            if (enabled) gtk_style_context_add_class(context, name);
            else gtk_style_context_remove_class(context, name);
        }
        const auto& icons = module->config["format-icons"];
        std::string icon;
        for (const auto& key : {std::to_string(id), space.active ? std::string("active") : "",
                               space.urgent ? std::string("urgent") : "", space.empty ? std::string("empty") : "", std::string("default")}) {
            if (!key.empty() && icons[key].isString()) { icon = icons[key].asString(); break; }
        }
        std::string label = module->config.get("format", "{id}").asString();
        replace(label, "{id}", std::to_string(id));
        replace(label, "{name}", space.name);
        replace(label, "{icon}", icon);
        gtk_button_set_label(GTK_BUTTON(button), label.c_str());
        gtk_box_reorder_child(GTK_BOX(module->box), button, position++);
        gtk_widget_show_all(button);
    }
}
extern "C" void* wbcffi_init(const Init* api, const Entry* entries, size_t count) {
    auto* module = new Module;
    module->api = *api;
    for (size_t i = 0; i < count; ++i) module->config[entries[i].key] = parse(entries[i].value);
    module->box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_name(module->box, "workspaces");
    gtk_container_add(api->root(api->obj), module->box);
    gtk_widget_show(module->box);
    module->worker = std::thread([module] {
        int events = -1;
        while (module->running) {
            if (events < 0) events = connectSocket(".socket2.sock");
            auto spaces = parse(request("j/workspaces"));
            auto monitors = parse(request("j/monitors"));
            auto active = parse(request("j/activeworkspace"));
            if (spaces.isArray() && monitors.isArray() && active["id"].isInt()) {
                auto snapshot = collect(spaces, monitors, active["id"].asInt(), module->config["persistent-workspaces"]);
                { std::lock_guard lock(module->mutex); module->snapshot = std::move(snapshot); }
                if (module->running) module->api.update(module->api.obj);
            }
            // Event-driven updates; retry after a compositor restart. No subprocess polling.
            pollfd event{events, POLLIN, 0};
            if (poll(&event, 1, 1000) > 0) {
                char buffer[8192];
                if (!(event.revents & POLLIN) || recv(events, buffer, sizeof(buffer), 0) <= 0) {
                    close(events); events = -1;
                }
            }
        }
        if (events >= 0) close(events);
    });
    return module;
}
extern "C" void wbcffi_update(void* instance) { render(static_cast<Module*>(instance)); }
extern "C" void wbcffi_deinit(void* instance) {
    auto* module = static_cast<Module*>(instance);
    module->running = false;
    module->worker.join();
    delete module;
}
