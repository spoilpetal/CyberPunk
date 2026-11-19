# Cyberpunk Design System — v0.1

## Colour palette
- Background: #090D16
- Surface: #111827
- Elevated surface: #171020
- Primary accent: #00E5FF
- Secondary accent: #FF36C7
- Tertiary accent: #A78BFA
- Main text: #E8F7FF
- Secondary text: #9BA9BC
- Border: #263449
- Warning: #FFB84D
- Error: #FF456A
- Success: #42F5B3

## Visual principles
- Dark futuristic robotics interface.
- Neon accents used selectively.
- Glass-like panels with restrained transparency.
- Thin technical borders and subtle glow.
- Readable typography and clear focus indicators.
- Avoid excessive animations and resource-heavy effects.

## Shell integration
The installer supplies a Night City Bash prompt with red, yellow, white, and cyan accents. It also includes region screenshot, Waybar toggle, Dunst startup, and safe Hyprland exit helpers. It is sourced from a dedicated file under `~/.local/share/cyberpunk-theme/shell/` through a managed block in `~/.bashrc`. The installer preserves all content outside that block and backs up the original file.

## Desktop integration
The portal preference uses GTK for general/file-chooser requests and Hyprland for screencasting and screenshots. PipeWire PulseAudio compatibility is installed for applications that expect a PulseAudio server.

## Compatibility
Each application receives its own configuration. Use the appropriate styling technology for each application. The Hyprland configuration uses the Lua configuration interface and must be checked against the target Hyprland version before first graphical login.

## Safety
- Never format disks or partitions.
- Never delete user documents.
- Back up existing configurations before replacing them.
- Do not enable or reconfigure a display manager automatically.
- Support file deployment from pure TTY; the graphical session still requires target hardware/runtime validation.
