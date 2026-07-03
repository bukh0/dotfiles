/* See LICENSE file for copyright and license details. */

/* appearance */
static const unsigned int borderpx  = 1;        /* border pixel of windows */
static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const char *fonts[]          = { "monospace:size=10" };
static const char dmenufont[]       = "monospace:size=10";
static const char col_gray1[]       = "#222222";
static const char col_gray2[]       = "#444444";
static const char col_gray3[]       = "#bbbbbb";
static const char col_gray4[]       = "#eeeeee";
//ADDED COLOURS. PURE
static const char col_black1[]       = "#000000";
static const char col_white1[]       = "#ffffff";
static const char col_red1[]         = "#ff0000";
static const char col_green1[]       = "#00ff00";
static const char col_blue1[]        = "#0000ff";
static const char col_yellow1[]      = "#ffff00";
static const char col_cyan1[]        = "#00ffff";
static const char col_magenta1[]     = "#ff00ff";
static const char col_cyan[]        = "#005577";
//ADDED COLOURS, LIGHTER (DIM?)
static const char col_black2[]       = "#1e1e2e";
static const char col_white2[]       = "#cdd6f4";
static const char col_red2[]         = "#f38ba8";
static const char col_green2[]       = "#a6e3a1";
static const char col_blue2[]        = "#89b4fa";
static const char col_yellow2[]      = "#f9e2af";
static const char col_cyan2[]        = "#94e2d5";
static const char col_magenta2[]     = "#cba6f7";
static const char *colors[][3]      = {
	/*               fg         bg         border   */
	[SchemeNorm] = { col_gray3, col_gray2, col_gray1 },
	[SchemeSel]  = { col_black1, col_gray2,  col_gray1  },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class      instance    title       tags mask     isfloating   monitor */
{ "Gimp",     NULL,       NULL,       0,            1,           -1 },
	{ "Firefox",  NULL,       NULL,       1 << 8,       0,           -1 },
	{ "discord",  NULL,       NULL,       1 << 8,       0,           -1 },
};
/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
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
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont, "-nb", col_gray1, "-nf", col_gray3, "-sb", col_cyan, "-sf", col_gray4, NULL };
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
  { MODKEY,                       XK_r,      resetlayout,    {0}},
  { MODKEY,                       XK_f,      togglemonocle,    {0}},
  { MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
	{ MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
	{ MODKEY,                       XK_h,      setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,      setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Return, zoom,           {0} },
	{ MODKEY,                       XK_Tab,    view,           {0} },
	{ MODKEY,                       XK_q,      killclient,     {0} },
	{ MODKEY|ShiftMask,             XK_l,      spawn,          {.v = slockcmd } },
  { MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
	{ MODKEY|ShiftMask,             XK_f,      setlayout,      {.v = &layouts[1]} },
	//{ MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} },
  { MODKEY,                       XK_w,      spawn,          {.v = wpcmd } },
	{ MODKEY,                       XK_space,  setlayout,      {0} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
	{ MODKEY,                       XK_0,      view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period, focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
  { MODKEY,                       XK_h,      spawn,          {.v = configmenucmd } },
  { MODKEY,                       XK_Print,  spawn, {.v = shotfull } },
	{ ShiftMask,                    XK_Print,  spawn, {.v = shotarea } },
	{ ControlMask,                  XK_Print,  spawn, {.v = shotclip } },
	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} },
	{ 0, XF86XK_AudioRaiseVolume,   spawn, {.v = upvol } },
	{ 0, XF86XK_AudioLowerVolume,   spawn, {.v = downvol } },
	{ 0, XF86XK_AudioMute,          spawn, {.v = mutevol } },
	{ 0, XF86XK_AudioMicMute,       spawn, {.v = mutemic } },
	{ 0, XF86XK_MonBrightnessUp,    spawn, {.v = upbl } },
	{ 0, XF86XK_MonBrightnessDown,  spawn, {.v = downbl } },
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
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
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

