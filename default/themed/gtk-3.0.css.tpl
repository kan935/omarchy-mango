/*
 * Omarchy palette for GTK3.
 * The active GTK theme supplies the widgets; these named colors tint them.
 */

@define-color accent_color {{ accent }};
@define-color accent_bg_color {{ accent }};
@define-color accent_fg_color {{ background }};

@define-color destructive_bg_color {{ color1 }};
@define-color destructive_fg_color {{ background }};
@define-color error_bg_color {{ color1 }};
@define-color error_fg_color {{ background }};
@define-color warning_bg_color {{ color3 }};
@define-color warning_fg_color {{ background }};
@define-color success_bg_color {{ color2 }};
@define-color success_fg_color {{ background }};

@define-color window_bg_color {{ background }};
@define-color window_fg_color {{ foreground }};
@define-color view_bg_color {{ background }};
@define-color view_fg_color {{ foreground }};

@define-color headerbar_bg_color {{ color0 }};
@define-color headerbar_fg_color {{ foreground }};
@define-color headerbar_backdrop_color @window_bg_color;

@define-color popover_bg_color {{ color0 }};
@define-color popover_fg_color {{ foreground }};

@define-color card_bg_color {{ color0 }};
@define-color card_fg_color {{ foreground }};

@define-color dialog_bg_color {{ background }};
@define-color dialog_fg_color {{ foreground }};

@define-color overview_bg_color {{ color0 }};
@define-color overview_fg_color {{ foreground }};

@define-color sidebar_bg_color {{ color0 }};
@define-color sidebar_fg_color {{ foreground }};
@define-color sidebar_backdrop_color @window_bg_color;
@define-color sidebar_border_color @window_bg_color;

@define-color secondary_sidebar_bg_color {{ background }};
@define-color secondary_sidebar_fg_color {{ foreground }};

/* GTK3 theme aliases */
@define-color theme_bg_color @window_bg_color;
@define-color theme_fg_color @window_fg_color;
@define-color theme_base_color @view_bg_color;
@define-color theme_text_color @view_fg_color;
@define-color theme_selected_bg_color @accent_bg_color;
@define-color theme_selected_fg_color @accent_fg_color;
@define-color insensitive_bg_color {{ color0 }};
@define-color insensitive_fg_color {{ color7 }};
@define-color base_color @view_bg_color;
@define-color text_color @view_fg_color;
@define-color selected_bg_color @accent_bg_color;
@define-color selected_fg_color @accent_fg_color;
@define-color borders {{ color8 }};
@define-color unfocused_borders {{ color0 }};

/* Focused selection states */
@define-color theme_unfocused_fg_color @window_fg_color;
@define-color theme_unfocused_text_color @view_fg_color;
@define-color theme_unfocused_bg_color @window_bg_color;
@define-color theme_unfocused_base_color @window_bg_color;
@define-color theme_unfocused_selected_bg_color @accent_bg_color;
@define-color theme_unfocused_selected_fg_color @accent_fg_color;

@define-color link_color {{ color4 }};
@define-color link_visited_color {{ color5 }};
@define-color placeholder_text_color {{ color7 }};
