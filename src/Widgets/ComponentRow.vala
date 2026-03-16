/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
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

public class DateTime.ComponentRow : Gtk.ListBoxRow {
    public GLib.DateTime date { get; construct; }
    public unowned ICal.Component component { get; construct; }
    public unowned E.SourceSelectable source_selectable { get; construct; }

    public GLib.DateTime start_time { get; private set; }
    public GLib.DateTime? end_time { get; private set; }
    public bool is_allday { get; private set; default = false; }

    private static Services.TimeManager time_manager;
    private static Gtk.CssProvider css_provider;

    private Gtk.Grid grid;
    private Gtk.Image component_image;
    private Gtk.Label name_label;
    private Gtk.Label time_label;

    public ComponentRow (GLib.DateTime date, ICal.Component component, E.Source source) {
        unowned E.SourceSelectable? source_selectable = null;

        if (source.has_extension (E.SOURCE_EXTENSION_TASK_LIST)) {
            source_selectable = (E.SourceSelectable?) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
        } else {
            source_selectable = (E.SourceSelectable?) source.get_extension (E.SOURCE_EXTENSION_CALENDAR);
        }

        Object (
            component: component,
            date: date,
            source_selectable: source_selectable
        );
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/EventRow.css");

        time_manager = Services.TimeManager.get_default ();
    }

    construct {
        var dt_start = component.get_dtstart ();
        if (dt_start.is_date ()) {
            // Don't convert timezone for date with only day info, leave it at midnight UTC
            start_time = Util.ical_to_date_time (dt_start);
        } else {
            start_time = Util.ical_to_date_time (dt_start).to_local ();
        }

        if (!(source_selectable is E.SourceTaskList)) {
            var dt_end = component.get_dtend ();
            if (dt_end.is_date ()) {
                // Don't convert timezone for date with only day info, leave it at midnight UTC
                end_time = Util.ical_to_date_time (dt_end);
            } else {
                end_time = Util.ical_to_date_time (dt_end).to_local ();
            }

            if (end_time != null && Util.is_the_all_day (start_time, end_time)) {
                is_allday = true;
            }
        }

        var icon_name = "office-calendar-symbolic";
        if (source_selectable is E.SourceTaskList) {
            icon_name = "office-task-symbolic";
        } else if (end_time == null) {
            icon_name = "alarm-symbolic";
        }

        component_image = new Gtk.Image.from_icon_name (icon_name) {
            valign = Gtk.Align.START
        };
        component_image.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        name_label = new Gtk.Label (component.get_summary ()) {
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END,
            lines = 3,
            max_width_chars = 30,
            wrap = true,
            wrap_mode = Pango.WrapMode.WORD_CHAR,
            xalign = 0
        };
        name_label.add_css_class ("title");
        name_label.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        time_label = new Gtk.Label (null) {
            use_markup = true,
            xalign = 0,
        };
        time_label.add_css_class (Granite.CssClass.DIM);

        grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_top = 3,
            margin_bottom = 3,
            margin_start = 6,
            margin_end = 6
        };
        grid.attach (component_image, 0, 0);
        grid.attach (name_label, 1, 0);
        if (!is_allday) {
            grid.attach (time_label, 1, 1);
        }

        grid.add_css_class ("event");
        grid.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        child = grid;

        set_color ();
        source_selectable.notify["color"].connect (set_color);

        update_timelabel ();
        time_manager.notify["is-12h"].connect (update_timelabel);
    }

    private void update_timelabel () {
        var time_format = Granite.DateTime.get_default_time_format (time_manager.is_12h);
        if (source_selectable is E.SourceTaskList) {
            time_label.label = "<small>Due by %s</small>".printf (start_time.format (time_format));
        } else {
            time_label.label = "<small>%s – %s</small>".printf (start_time.format (time_format), end_time.format (time_format));
        }
    }

    private void set_color () {
        Util.set_component_calendar_color (source_selectable, grid);
        Util.set_component_calendar_color (source_selectable, component_image);
        Util.set_component_calendar_color (source_selectable, name_label);
        Util.set_component_calendar_color (source_selectable, time_label);
    }
}
