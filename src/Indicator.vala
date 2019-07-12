/*
 * Copyright (c) 2011-2016 elementary LLC. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 */

public class DateTime.Indicator : Wingpanel.Indicator {
    private Widgets.PanelLabel panel_label;
    private Gtk.Grid main_grid;
    private Widgets.Calendar calendar;
    private Widgets.ControlHeader heading;
    private Gtk.ListBox event_grid;
    private Gtk.Label no_events_label;
    private uint update_events_idle_source = 0;

    public Indicator () {
        Object (
            code_name: Wingpanel.Indicator.DATETIME,
            display_name: _("Date & Time"),
            description: _("The date and time indicator")
        );
    }

    construct {
        visible = true;
    }

    public override Gtk.Widget get_display_widget () {
        if (panel_label == null) {
            panel_label = new Widgets.PanelLabel ();
        }

        return panel_label;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            calendar = new Widgets.Calendar ();

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/ControlHeader.css");

            var settings_button = new Gtk.ModelButton ();
            settings_button.text = _("Date & Time Settings…");

            var header_label = new Gtk.Label (_("Events"));
            header_label.get_style_context ().add_class ("header-label");
            header_label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            header_label.halign = Gtk.Align.START;
            header_label.width_chars = 13;
            header_label.xalign = 0;

            var cal_icon = new Gtk.Image.from_icon_name ("office-calendar", Gtk.IconSize.LARGE_TOOLBAR);
            cal_icon.halign = Gtk.Align.END;
            var cal_button = new Gtk.Button ();
            cal_button.set_image (cal_icon);
            cal_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            cal_button.get_style_context ().remove_class (Gtk.STYLE_CLASS_BUTTON);
            cal_button.get_style_context ().remove_class ("text-button");
            cal_button.set_tooltip_text (_("Open Calendar"));

            var header_grid = new Gtk.Grid ();
            header_grid.column_spacing = 6;
            header_grid.valign = Gtk.Align.CENTER;
            header_grid.margin = 6;
            header_grid.attach (header_label, 0, 0);
            header_grid.attach (cal_button, 1, 0);

            var sep = new Gtk.Separator (Gtk.Orientation.VERTICAL);

            no_events_label = new Gtk.Label (_("No Events Scheduled In This Day"));
            no_events_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
            no_events_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            no_events_label.width_chars = 20;
            no_events_label.max_width_chars = 20;
            no_events_label.set_line_wrap (true);
            no_events_label.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
            no_events_label.set_justify (Gtk.Justification.CENTER);
            no_events_label.halign = Gtk.Align.CENTER;

            heading = new Widgets.ControlHeader ();
            heading.margin = 9;

            main_grid = new Gtk.Grid ();
            main_grid.attach (heading, 0, 0);
            main_grid.attach (calendar, 0, 1);
            main_grid.attach (new Wingpanel.Widgets.Separator (), 0, 2);
            main_grid.attach (settings_button, 0, 3);
            main_grid.attach (sep, 1, 0, 1, 9);
            main_grid.attach (header_grid, 2, 0);
            main_grid.attach (no_events_label, 2, 1);

            calendar.day_double_click.connect (() => {
                close ();
            });

            calendar.selection_changed.connect ((date) => {
                idle_update_events ();
            });

            heading.center_clicked.connect (() => {
                calendar.show_today ();
            });

            cal_button.clicked.connect (() => {
                open_maya ();
                this.close ();
            });

            settings_button.clicked.connect (() => {
                try {
                    AppInfo.launch_default_for_uri ("settings://time", null);
                } catch (Error e) {
                    warning ("Failed to open time and date settings: %s", e.message);
                }
            });
        }

        return main_grid;
    }

    private void update_events_model (E.Source source, Gee.Collection<E.CalComponent> events) {
        idle_update_events ();
    }

    private void idle_update_events () {
        if (update_events_idle_source > 0) {
            GLib.Source.remove (update_events_idle_source);
        }

        update_events_idle_source = GLib.Idle.add (update_events);
    }

    private bool update_events () {
        if (event_grid != null) {
            event_grid.destroy ();
        }

        if (calendar.selected_date == null) {
            update_events_idle_source = 0;
            return GLib.Source.REMOVE;
        }

        var events = Widgets.CalendarModel.get_default ().get_events (calendar.selected_date);
        if (events.size == 0) {
            update_events_idle_source = 0;
            no_events_label.visible = true;
            return GLib.Source.REMOVE;
        }

        event_grid = new Gtk.ListBox ();
        foreach (var e in events) {
            var menuitem_icon = new Gtk.Image.from_icon_name (e.get_icon (), Gtk.IconSize.MENU);
            menuitem_icon.valign = Gtk.Align.CENTER;

            var menuitem_label = new Gtk.Label (e.get_label ());
            menuitem_label.hexpand = true;
            menuitem_label.lines = 3;
            menuitem_label.ellipsize = Pango.EllipsizeMode.END;
            menuitem_label.width_chars = 20;
            menuitem_label.wrap = true;
            menuitem_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            menuitem_label.xalign = 0;

            var menuitem_box = new Gtk.Grid ();
            menuitem_box.add (menuitem_icon);
            menuitem_box.add (menuitem_label);

            var menuitem = new Gtk.Button ();
            menuitem.margin_top = 6;
            menuitem.margin = 9;
            menuitem.add (menuitem_box);

            var style_context = menuitem.get_style_context ();
            style_context.add_class (Gtk.STYLE_CLASS_MENUITEM);
            style_context.remove_class (Gtk.STYLE_CLASS_BUTTON);
            style_context.remove_class ("text-button");

            event_grid.add (menuitem);

            /* Color menuitem per calendar source of event */
            var css_class = Util.get_style_calendar_color (e.cal);
            menuitem.get_style_context ().add_class (css_class);

            e.cal.notify["color"].connect (() => {
                Util.get_style_calendar_color (e.cal); /* Redefines same class */
            });

            menuitem.clicked.connect (() => {
                calendar.show_date_in_maya (e.date);
                this.close ();
            });
        }

        event_grid.show_all ();
        main_grid.attach (event_grid, 2, 1);
        no_events_label.visible = false;
        update_events_idle_source = 0;
        return GLib.Source.REMOVE;
    }

    public void open_maya () {
        var command = "io.elementary.calendar";

        try {
            var appinfo = AppInfo.create_from_commandline (command, null, AppInfoCreateFlags.NONE);
            appinfo.launch_uris (null, null);
        } catch (GLib.Error e) {
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Unable To Launch Calendar"),
                _("The program \"io.elementary.calendar\" may not be installed"),
                "dialog-error"
            );
            dialog.show_error_details (e.message);
            dialog.run ();
            dialog.destroy ();
        }
    }

    public override void opened () {
        calendar.show_today (); 

        Widgets.CalendarModel.get_default ().events_added.connect (update_events_model);
        Widgets.CalendarModel.get_default ().events_updated.connect (update_events_model);
        Widgets.CalendarModel.get_default ().events_removed.connect (update_events_model);
    }

    public override void closed () {
        Widgets.CalendarModel.get_default ().events_added.disconnect (update_events_model);
        Widgets.CalendarModel.get_default ().events_updated.disconnect (update_events_model);
        Widgets.CalendarModel.get_default ().events_removed.disconnect (update_events_model);
    }
}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating DateTime Indicator");
    var indicator = new DateTime.Indicator ();

    return indicator;
}
