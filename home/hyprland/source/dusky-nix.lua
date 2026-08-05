-- -------------------------------------------------------------------------------------------------
-- dusky-nix overrides
-- -------------------------------------------------------------------------------------------------
-- Loaded AFTER every upstream source/*.lua file, so anything set here wins.
--
-- Everything upstream does that works unmodified on NixOS is left alone — script
-- paths resolve through the Nix shim tree (see packages/user-scripts.nix), so
-- upstream's files are deployed verbatim. This file holds only the deltas:
--   * settings this config tunes differently from upstream
--   * binds upstream doesn't have, or points at a script we don't package
--   * window rules for apps upstream doesn't know about
--
-- ponytail: deltas only. If upstream adopts one of these, delete it from here.

local osd = "dusky-osd-router"

-- -------------------------------------------------------------------------------------------------
-- APPEARANCE
-- -------------------------------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in          = 6,
        gaps_out         = 12,
        gaps_workspaces  = 0,
        resize_on_border = false,
    },
    decoration = {
        rounding_power   = 6.0,
        -- Opaque windows + ignore_opacity blur = frosted glass only where a
        -- window rule actually asks for transparency.
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_strength     = 0.2,
        dim_special      = 0.8,
        blur = {
            size       = 3,
            passes     = 4,
            contrast   = 1.5,
            brightness = 2.0,
        },
        shadow = {
            enabled      = false,
            range        = 35,
            render_power = 2,
        },
    },
    misc = {
        force_default_wallpaper  = 1,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },
    binds = {
        allow_pin_fullscreen = true,
    },
})

-- -------------------------------------------------------------------------------------------------
-- INPUT
-- -------------------------------------------------------------------------------------------------
hl.config({
    input = {
        numlock_by_default = true,
    },
    gestures = {
        workspace_swipe_distance     = 300,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_invert       = true,
        workspace_swipe_create_new   = true,
        workspace_swipe_forever      = false,
    },
})

-- -------------------------------------------------------------------------------------------------
-- GESTURES
-- upstream keeps these in source/trackpad.lua, which its hyprland.lua doesn't load.
-- -------------------------------------------------------------------------------------------------
hl.gesture({ fingers = 3, direction = "up",       action = function() hl.exec_cmd("hyprctl dispatch hyprexpo:expo toggle") end })
hl.gesture({ fingers = 3, direction = "left",     action = function() hl.exec_cmd("dusky-rofi-mako") end })
hl.gesture({ fingers = 3, direction = "down",     action = function() hl.exec_cmd(osd .. " --vol-mute") end })
hl.gesture({ fingers = 3, direction = "right",    action = function() hl.exec_cmd(osd .. " --play-pause") end })
hl.gesture({ fingers = 4, direction = "left",     action = function() hl.exec_cmd(osd .. " --bright-down 10") end })
hl.gesture({ fingers = 4, direction = "right",    action = function() hl.exec_cmd(osd .. " --bright-up 10") end })
hl.gesture({ fingers = 4, direction = "up",       action = function() hl.exec_cmd(osd .. " --vol-up 10") end })
hl.gesture({ fingers = 4, direction = "down",     action = function() hl.exec_cmd(osd .. " --vol-down 10") end })
hl.gesture({ fingers = 3, direction = "pinchout", action = function() hl.exec_cmd("hyprlock --immediate") end })
hl.gesture({ fingers = 3, direction = "pinchin",  action = function() hl.exec_cmd("slurp | grim -g - - | swappy -f -") end })
hl.gesture({ fingers = 4, direction = "pinchout", action = function() hl.exec_cmd("dusky-rofi-mako") end })

-- -------------------------------------------------------------------------------------------------
-- KEYBINDS
-- -------------------------------------------------------------------------------------------------
hl.unbind("CTRL + SPACE")
hl.bind("CTRL + SPACE", hl.dsp.exec_cmd("uwsm-app -- pkill rofi; dusky-rofi-wallpaper"), { description = "Rofi Wallpaper Selector" })
hl.bind("ALT + 8", hl.dsp.exec_cmd("uwsm-app -- blanket"), { description = "Ambient Noise (Blanket)" })
hl.unbind("SUPER + APOSTROPHE")
hl.bind("SUPER + apostrophe", hl.dsp.exec_cmd("uwsm-app -- dusky-theme-ctl random"), { description = "Cycle Wallpaper" })
hl.bind("ALT + 7", hl.dsp.exec_cmd("hyprctl keyword monitor eDP-1,1920x1080@48,0x0,1.6 && sleep 2 && hyprctl keyword misc:vrr 0"), { locked = true, description = "Set Refresh rate to 48Hz Asus Tuf" })
hl.bind("ALT + 8", hl.dsp.exec_cmd("hyprctl keyword monitor eDP-1,1920x1080@144,0x0,1.6 && sleep 2 && hyprctl keyword misc:vrr 1"), { locked = true, description = "Set Refresh rate to 144Hz Asus Tuf" })
hl.unbind("ALT + SUPER + W")
hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("uwsm-app -- dusky-waybars --toggle"), { description = "Waybar Swap Configs" })
hl.unbind("ALT + SHIFT + SUPER + W")
hl.bind("SUPER + ALT + SHIFT + W", hl.dsp.exec_cmd("uwsm-app -- dusky-waybars --back_toggle"), { description = "Waybar Swap Configs" })
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("uwsm-app -- looking-glass-client -f /dev/shm/looking-glass -m KEY_F6"), { description = "Looking Glass VM" })
hl.bind("ALT + R", hl.dsp.exec_cmd("hyprctl reload"), { locked = true, description = "Reload Hyprland" })
hl.bind("ALT + V", hl.dsp.exec_cmd("uwsm-app -- dusky-sliders"), { description = "Volume/Brightness & Nightlight Slider" })
hl.bind("XF86Launch3", hl.dsp.exec_cmd("uwsm-app -- " .. terminal .. " --class asusctl.sh -e sudo dusky-asus-control"), { description = "ASUS Control" })
hl.unbind("ALT + SUPER + X")
hl.bind("SUPER + ALT + X", hl.dsp.exec_cmd("uwsm-app -- pkill rofi; dusky-rofi-shader"), { description = "Shader Menu" })
hl.bind("SUPER + ALT + SHIFT + X", hl.dsp.exec_cmd("hyprshade off"), { locked = true, description = "Disable Shader" })
hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd("uwsm-app -- pkill rofi; rofi -modi \"clipboard:dusky-rofi-cliphist\" -show clipboard"), { description = "Clipboard History" })
hl.unbind("SUPER + S")
hl.bind("SUPER + S", hl.dsp.exec_cmd("dusky-screenshot --region --freeze --notify"), { description = "Quick Screenshot" })
hl.unbind("ALT + SUPER + S")
hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("dusky-screenshot --region --freeze --annotate --notify --tool arrow"), { description = "Screenshot and Annotation" })
hl.unbind("ALT + SUPER + O")
hl.bind("SUPER + ALT + O", hl.dsp.exec_cmd("uwsm-app -- " .. terminal .. " --class ollama_terminal.sh -e dusky-ollama-terminal"), { description = "AI LLM Ollama Chat" })
hl.bind("SUPER + CTRL + O", hl.dsp.exec_cmd("uwsm-app -- dusky-voice-reset"), { description = "Voice Assistant Reset" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("uwsm-app -- dusky-voice-interrupt"), { description = "Voice Proceed / double-tap Interrupt" })
hl.bind("SUPER + ALT + O", hl.dsp.exec_cmd("uwsm-app -- dusky-kokoro-voice"), { description = "TTS Voice Picker" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close Window" })
hl.bind("ALT + P", hl.dsp.exec_cmd(osd .. " --vol-mute"), { locked = true, description = "Mute Audio" })
hl.bind("ALT + M", hl.dsp.exec_cmd("dusky-mono-audio"), { locked = true, description = "Mono Audio Toggle" })
hl.bind("ALT + O", hl.dsp.exec_cmd("uwsm-app -- dusky-audio-switch"), { locked = true, description = "Switch Audio Output" })
hl.bind("ALT + I", hl.dsp.exec_cmd("uwsm-app -- dusky-mic-switch"), { locked = true, description = "Switch Mic Input" })

-- -------------------------------------------------------------------------------------------------
-- WINDOW RULES
-- -------------------------------------------------------------------------------------------------

hl.window_rule({
    name = "hyprsunset_slider.sh",
    match = {
        title = "^(Hyprsunset)$",
    },
    float = true,
    pin = true,
    -- calculated by screen/s half and then half size of the width of the window to be in the center. 
    move = "(monitor_w/2-210) (monitor_h/2-220)",
    size = "420 120",
})

hl.window_rule({
    name = "brightness_slider.sh",
    match = {
        title = "^(Brightness)$",
    },
    float = true,
    pin = true,
    move = "(monitor_w/2-210) (monitor_h/2-60)",
    size = "420 120",
})

hl.window_rule({
    name = "volume_slider.sh",
    match = {
        title = "^(Volume)$",
    },
    float = true,
    pin = true,
    move = "(monitor_w/2-210) (monitor_h/2+100)",
    size = "420 120",
})

hl.window_rule({
    name = "transparent-blanket",
    match = {
        class = "^(com\\.rafaelmardojai\\.Blanket)$",
    },
    opacity = "0.8 override 0.7 override",
})

hl.window_rule({
    name = "02_openssh_setup.sh",
    match = {
        class = "^(02_openssh_setup.sh)$",
    },
    float = true,
    size = "652 576",
    center = true,
})

hl.window_rule({
    name = "clipboard_persistance",
    match = {
        class = "^(clipboard_persistance.sh)$",
    },
    float = true,
    size = "589 529",
    center = true,
})

hl.window_rule({
    name = "io_monitor.sh",
    match = {
        class = "^(io_monitor.sh)$",
    },
    float = true,
    size = "943 247",
    center = true,
})

hl.window_rule({
    name = "090_paru_packages_optionalsh",
    match = {
        class = "^(090_paru_packages_optional\\.sh)$",
    },
    float = true,
    size = "831 572",
})

hl.window_rule({
    name = "dusky_monitor.sh",
    match = {
        class = "^(dusky_monitor.sh)$",
    },
    float = true,
    size = "802 469",
    center = true,
})

hl.window_rule({
    name = "dusky-voice-overlay",
    match = {
        class = "^(dusky-voice-overlay)$",
    },
    float = true,
    pin = true,
    size = "500 200",
    move = "(monitor_w-window_w-12) (monitor_h-window_h-50)",
    no_dim = true,
    opaque = true,
    no_focus = true,
    border_size = 0,
    animation = "slide bottom",
})

hl.window_rule({
    name = "dusky_network.sh",
    match = {
        class = "^(dusky_network.sh)$",
    },
    float = true,
    size = "741 579",
    center = true,
})

hl.window_rule({
    name = "dusky_control_center.py",
    match = {
        title = "^(Dusky Control Center)$",
        class = "^(com.github.dusky.controlcenter)$",
    },
    float = true,
    animation = "slide down",
    size = "(monitor_w*0.50) (monitor_h*0.92)",
    move = "(monitor_w*0.05) (monitor_h*0.05)",
    center = true,
})

hl.window_rule({
    name = "float_thunar_rename",
    match = {
        class = "Thunar",
        title = "^Rename.*$",
    },
    float = true,
})

hl.window_rule({
    name = "dusky_waybars.sh",
    match = {
        class = "^(dusky_waybars.sh)$",
    },
    float = true,
    size = "780 510",
    center = true,
})

hl.layer_rule({
    name = "rofi",
    match = {
        namespace = "rofi",
    },
    --animation = slide down
    --dim_around = on
})

hl.window_rule({
    name = "style-magic-workspace",
    match = {
        workspace = "special:magic",
    },
    border_color = primary,
    border_size = 1,
})
