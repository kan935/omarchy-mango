/*
 * Omarchy palette for GTK4 and libadwaita.
 * GTK4 does not accept a custom widget theme, so expose the palette as named
 * colors and CSS variables that libadwaita consumes.
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

@define-color theme_bg_color @window_bg_color;
@define-color theme_fg_color @window_fg_color;
@define-color theme_base_color @view_bg_color;
@define-color theme_text_color @view_fg_color;
@define-color theme_selected_bg_color @accent_bg_color;
@define-color theme_selected_fg_color @accent_fg_color;
@define-color insensitive_bg_color {{ color0 }};
@define-color insensitive_fg_color {{ color7 }};
@define-color borders {{ color8 }};

@define-color link_color {{ color4 }};
@define-color link_visited_color {{ color5 }};
@define-color placeholder_text_color {{ color7 }};

:root {
  --accent-color: {{ accent }};
  --accent-bg-color: {{ accent }};
  --accent-fg-color: {{ background }};

  --destructive-bg-color: {{ color1 }};
  --destructive-fg-color: {{ background }};

  --error-bg-color: {{ color1 }};
  --error-fg-color: {{ background }};
  --error-color: {{ color1 }};

  --warning-bg-color: {{ color3 }};
  --warning-fg-color: {{ background }};
  --warning-color: {{ color3 }};

  --success-bg-color: {{ color2 }};
  --success-fg-color: {{ background }};
  --success-color: {{ color2 }};

  --window-bg-color: {{ background }};
  --window-fg-color: {{ foreground }};

  --view-bg-color: {{ background }};
  --view-fg-color: {{ foreground }};

  --headerbar-bg-color: {{ color0 }};
  --headerbar-fg-color: {{ foreground }};
  --headerbar-backdrop-color: {{ background }};

  --popover-bg-color: {{ color0 }};
  --popover-fg-color: {{ foreground }};

  --card-bg-color: {{ color0 }};
  --card-fg-color: {{ foreground }};

  --dialog-bg-color: {{ background }};
  --dialog-fg-color: {{ foreground }};

  --overview-bg-color: {{ color0 }};
  --overview-fg-color: {{ foreground }};

  --sidebar-bg-color: {{ color0 }};
  --sidebar-fg-color: {{ foreground }};
  --sidebar-backdrop-color: {{ background }};
  --sidebar-border-color: {{ background }};

  --shade-color: rgba(0, 0, 0, 0.36);
}
