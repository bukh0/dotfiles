/* See LICENSE file for copyright and license details. */

/* appearance: Catppuccin Mocha, with quiet surfaces and a blue accent */
static const unsigned int borderpx  = 2;
static const unsigned int snap      = 32;
static const int showbar            = 1;
static const int topbar             = 1;
static const unsigned int barpadding = 10; /* extra vertical space */
static const unsigned int sidepadding = 22; /* total horizontal text padding */
static const char *fonts[]          = { "JetBrainsMono Nerd Font:size=10", "sans-serif:size=10" };
static const char dmenufont[]        = "JetBrainsMono Nerd Font:size=11";

static const char col_gray1[]       = "#181825";
static const char col_gray2[]       = "#313244";
static const char col_gray3[]       = "#a6adc8";
static const char col_gray4[]       = "#cdd6f4";
static const char col_cyan[]        = "#89b4fa";
static const char col_black2[]      = "#181825";

static const char *colors[][3]      = {
    /*                  fg          bg          border */
    [SchemeNorm]     = { col_gray3,  col_gray1,  col_gray2 },
    [SchemeSel]      = { col_cyan,   "#252539",  col_cyan  },
    [SchemeOccupied] = { col_gray4,  col_gray1,  col_gray2 },
    [SchemeTitle]    = { col_gray4,  col_gray1,  col_gray2 },
    [SchemeUrgent]   = { "#f38ba8",  "#302331",  "#f38ba8" },
};

/* tagging: all 9 workspaces */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
    /* xprop(1):
     *   WM_CLASS(STRING) = instance, class
     *   WM_NAME(STRING) = title
     */
    /* class      instance    title       tags mask     isfloating   monitor */
    { "Gimp",     NULL,       NULL,       0,            1,           -1 },
    { "Firefox",  NULL,       NULL,       1 << 4,       0,           -1 },
    { "discord",  NULL,       NULL,       1 << 4,       0,           -1 },
};

/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
    /* symbol     arrange function */
    { "󰕰",      tile },    /* clean tiled icon */
    { "󰉈",      NULL },    /* clean floating icon */
    { "󱒈",      monocle }, /* clean monocle icon */
};

/* key definitions */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
    { MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
    { MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *slockcmd[] = { "slock", NULL };
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = {
    "dmenu_run", "-i", "-m", dmenumon, "-p", "󰍉  Launch",
    "-fn", dmenufont, "-nb", col_gray1, "-nf", col_gray3,
    "-sb", col_cyan, "-sf", col_black2, NULL
};
static const char *configmenucmd[] = { "/home/bukh0/.local/bin/config-menu.sh", NULL };
static const char *termcmd[]  = { "kitty", NULL };
static const char *wpcmd[] = { "/home/bukh0/.local/bin/wallpaper-switcher.sh", NULL };
static const char *upvol[]   = { "/home/bukh0/.local/bin/hardware-osd.sh", "vol_up", NULL };
static const char *downvol[] = { "/home/bukh0/.local/bin/hardware-osd.sh", "vol_down", NULL };
static const char *mutevol[] = { "/home/bukh0/.local/bin/hardware-osd.sh", "vol_mute", NULL };
static const char *mutemic[] = { "/home/bukh0/.local/bin/hardware-osd.sh", "mic_mute", NULL };
static const char *shotfull[] = { "/home/bukh0/.local/bin/shot.sh", "full", NULL };
static const char *shotarea[] = { "/home/bukh0/.local/bin/shot.sh", "area", NULL };
static const char *shotclip[] = { "/home/bukh0/.local/bin/shot.sh", "clip", NULL };
static const char *upbl[]    = { "/home/bukh0/.local/bin/hardware-osd.sh", "bright_up", NULL };
static const char *downbl[]  = { "/home/bukh0/.local/bin/hardware-osd.sh", "bright_down", NULL };

static const Key keys[] = {
    /* modifier                     key        function        argument */
    { MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
    { MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
    { MODKEY,                       XK_b,      togglebar,      {0} },
    { MODKEY,                       XK_r,      resetlayout,    {0} },
    { MODKEY,                       XK_f,      togglemonocle,  {0} },
    { MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
    { MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
    { MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
    { MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
    { MODKEY,                       XK_h,      setmfact,       {.f = -0.05} },
    { MODKEY,                       XK_l,      setmfact,       {.f = +0.05} },
    { MODKEY|ShiftMask,             XK_Return, zoom,           {0} },
    { MODKEY,                       XK_Tab,    view,           {0} },
    { MODKEY,                       XK_q,      killclient,     {0} },
    { MODKEY|ShiftMask,             XK_l,      spawn,          {.v = slockcmd } },
    { MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
    { MODKEY|ShiftMask,             XK_f,      setlayout,      {.v = &layouts[1]} },
    { MODKEY,                       XK_w,      spawn,          {.v = wpcmd } },
    { MODKEY,                       XK_space,  setlayout,      {0} },
    { MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
    { MODKEY,                       XK_0,      view,           {.ui = ~0 } },
    { MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
    { MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
    { MODKEY,                       XK_period, focusmon,       {.i = +1 } },
    { MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
    { MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
    { MODKEY|ShiftMask,             XK_h,      spawn,          {.v = configmenucmd } },
    { MODKEY,                       XK_Print,  spawn,          {.v = shotfull } },
    { MODKEY|ControlMask,           XK_Print,  spawn,          {.v = shotarea } },
    { MODKEY|ShiftMask,             XK_Print,  spawn,          {.v = shotclip } },
    { MODKEY|ShiftMask,             XK_q,      quit,           {0} },
    { 0, XF86XK_AudioRaiseVolume,              spawn,          {.v = upvol } },
    { 0, XF86XK_AudioLowerVolume,              spawn,          {.v = downvol } },
    { 0, XF86XK_AudioMute,                     spawn,          {.v = mutevol } },
    { 0, XF86XK_AudioMicMute,                  spawn,          {.v = mutemic } },
    { 0, XF86XK_MonBrightnessUp,               spawn,          {.v = upbl } },
    { 0, XF86XK_MonBrightnessDown,             spawn,          {.v = downbl } },
    TAGKEYS(                        XK_1,                      0)
    TAGKEYS(                        XK_2,                      1)
    TAGKEYS(                        XK_3,                      2)
    TAGKEYS(                        XK_4,                      3)
    TAGKEYS(                        XK_5,                      4)
    TAGKEYS(                        XK_6,                      5)
    TAGKEYS(                        XK_7,                      6)
    TAGKEYS(                        XK_8,                      7)
    TAGKEYS(                        XK_9,                      8)
};

/* button definitions */
static const Button buttons[] = {
    /* click                event mask      button          function        argument */
    { ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
    { ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
    { ClkWinTitle,          0,              Button2,        zoom,           {0} },
    { ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
    { ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
    { ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
    { ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
    { ClkTagBar,            0,              Button1,        view,           {0} },
    { ClkTagBar,            0,              Button3,        toggleview,     {0} },
    { ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
    { ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};
