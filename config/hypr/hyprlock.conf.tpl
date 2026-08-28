background {
    monitor =
    path = __WALLPAPER__
    color = __BG__
    blur_passes = 2
    blur_size = 4
}

input-field {
    monitor =
    size = 250, 50
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.3
    dots_center = true
    outer_color = __OUTER__
    inner_color = __INNER__
    font_color = __FONT__
    check_color = __CHECK__
    fail_color = __FAIL__
    placeholder_text = <span foreground="__DIM__">Contraseña...</span>
    fade_on_empty = true
    position = 0, -40
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "<b>$(date +'%H')</b>"
    color = __HOUR__
    font_size = 110
    font_family = monospace
    position = 0, 235
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "<b>$(date +'%M')</b>"
    color = __MINUTE__
    font_size = 110
    font_family = monospace
    position = 0, 125
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] echo "$(date +'%A, %d %B')"
    color = __DATE__
    font_size = 18
    font_family = monospace
    position = 0, 40
    halign = center
    valign = center
}
