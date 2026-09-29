/* Catppuccin Mocha status bar for dwm's status2d renderer. */
const unsigned int interval = 2000;
static const char unknown_str[] = "—";
#define MAXLEN 2048

/* Battery colour changes for low charge; charging has its own icon. */
static const char *
battery_badge(const char *battery)
{
    static char badge[160];
    const char *value = battery_perc(battery), *state, *icon, *colour;
    int percent;

    if (!value)
        return "^c#6c7086^󰂑 —^d^";
    percent = atoi(value);
    state = battery_state(battery);
    colour = percent <= 15 ? "#f38ba8" : percent <= 30 ? "#f9e2af" : "#a6e3a1";
    icon = percent <= 15 ? "󰁺" : percent <= 30 ? "󰁼" :
           percent <= 60 ? "󰁿" : percent <= 85 ? "󰂁" : "󰁹";
    if (state && !strcmp(state, "+")) {
        icon = "󰂄";
        colour = "#a6e3a1";
    }
    snprintf(badge, sizeof badge, "^c%s^%s %d%%^d^", colour, icon, percent);
    return badge;
}

#define RESET "^d^"
#define SEP RESET "^f10^^c#585b70^|" RESET "^f10^"

static const struct arg args[] = {
    /* Compact clock and date, with a consistent divider between metrics. */
    { datetime, "^c#89b4fa^%s" SEP, "%H:%M · %a %d/%m" },
    { cpu_perc, "^c#cba6f7^CPU " RESET "%s%%" SEP, NULL },
    { ram_perc, "^c#f9e2af^RAM " RESET "%s%%" SEP, NULL },
    { battery_badge, "%s" SEP, "BAT0" },
    /* Preserve colons in SSIDs, avoid rescans, and replace markup carets. */
    { run_command, "^c#74c7ec^󰤨 ^c#a6adc8^%s" SEP,
      "ssid=$(timeout 1s iwgetid -r 2>/dev/null); "
      "if [ -z \"$ssid\" ]; then "
      "ssid=$(timeout 1s nmcli -e no -t -f active,ssid dev wifi --rescan no 2>/dev/null "
      "| awk 'substr($0,1,4) == \"yes:\" { print substr($0,5); exit }'); fi; "
      "printf '%s' \"${ssid:-Offline}\" | tr '^' '?'" },
    { run_command, "%s",
      "if timeout 1s bluetoothctl show 2>/dev/null | grep -q '^[[:space:]]*Powered: yes'; "
      "then printf '^c#89dceb^󰂯 On^d^'; else printf '^c#6c7086^󰂲 Off^d^'; fi" },
};
