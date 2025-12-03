/*-
 * Copyright (c) 2011–2018 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Maxwell Barvian
 *              Corentin Noël <corentin@elementaryos.org>
 */

public class DateTime.Widgets.CalendarView : Gtk.Grid {
    public signal void day_double_click ();
    public signal void event_updates ();
    public signal void selection_changed (GLib.DateTime? new_date);

    public GLib.DateTime? selected_date { get; private set; }

    private Adw.Carousel carousel;
    private uint position;
    private int rel_postion;
    private CalendarModel events_model;
    private CalendarModel tasks_model;
    private GLib.DateTime start_month;
    private DateTime.Widgets.Grid start_month_grid;
    private Gtk.Label label;
    private bool showtoday;

    construct {
        label = new Gtk.Label (new GLib.DateTime.now_local ().format (_("%OB, %Y"))) {
            hexpand = true,
            margin_start = 6,
            xalign = 0,
            width_chars = 13
        };

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/ControlHeader.css");

        unowned var label_style_context = label.get_style_context ();
        label_style_context.add_class (Granite.STYLE_CLASS_ACCENT);
        label_style_context.add_class ("header-label");
        label_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var left_button = new Gtk.Button.from_icon_name ("pan-start-symbolic");
        var center_button = new Gtk.Button.from_icon_name ("office-calendar-symbolic") {
            tooltip_text = _("Go to today's date")
        };
        var right_button = new Gtk.Button.from_icon_name ("pan-end-symbolic");

        var box_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            margin_end = 6,
            valign = Gtk.Align.CENTER
        };
        box_buttons.get_style_context ().add_class (Granite.STYLE_CLASS_LINKED);
        box_buttons.append (left_button);
        box_buttons.append (center_button);
        box_buttons.append (right_button);

        var new_event_button = new Gtk.Button.from_icon_name ("appointment-new-symbolic");
        new_event_button.tooltip_text = _("New event");

        events_model = CalendarModel.get_default (ECal.ClientSourceType.EVENTS);
        tasks_model = CalendarModel.get_default (ECal.ClientSourceType.TASKS);
        start_month = Util.get_start_of_month ();

        start_month_grid = create_grid ();
        start_month_grid.set_range (events_model.data_range, events_model.month_start);
        start_month_grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);

        events_model.change_month (-1);
        tasks_model.change_month (-1);
        var left_grid = create_grid ();
        left_grid.set_range (events_model.data_range, events_model.month_start);
        left_grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);

        events_model.change_month (2);
        tasks_model.change_month (2);
        var right_grid = create_grid ();
        right_grid.set_range (events_model.data_range, events_model.month_start);
        right_grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);
        events_model.change_month (-1);
        tasks_model.change_month (-1);

        carousel = new Adw.Carousel () {
            interactive = true,
            hexpand = true,
            vexpand = true,
            spacing = 15
        };

        carousel.append (left_grid);
        carousel.append (start_month_grid);
        carousel.append (right_grid);
        carousel.scroll_to (start_month_grid, false);

        position = 1;
        rel_postion = 0;
        showtoday = false;

        column_spacing = 6;
        row_spacing = 6;
        margin_start = margin_end = 10;
        attach (label, 0, 0);
        attach (box_buttons, 1, 0);
        attach (new_event_button, 2, 0);
        attach (carousel, 0, 1, 3);

        left_button.clicked.connect (() => {
            carousel.scroll_to (carousel.get_nth_page ((uint) Math.round (carousel.position) - 1), true);
        });

        right_button.clicked.connect (() => {
            carousel.scroll_to (carousel.get_nth_page ((uint) Math.round (carousel.position) + 1), true);
        });

        center_button.clicked.connect (() => {
            show_today ();
        });

        new_event_button.clicked.connect (() => {
            open_maya_with_options (selected_date, true);
        });

        carousel.page_changed.connect ((index) => {
            events_model.change_month (-rel_postion);
            tasks_model.change_month (-rel_postion);
            if (position > index) {
                rel_postion--;
                position--;
            } else if (position < index) {
                rel_postion++;
                position++;
            } else if (showtoday) {
                showtoday = false;
                rel_postion = 0;
                position = (int) carousel.get_position ();
                label.label = events_model.month_start.format (_("%OB, %Y"));
                start_month_grid.set_focus_to_today ();
                return;
            } else {
                events_model.change_month (rel_postion);
                tasks_model.change_month (rel_postion);
                return;
            }
            events_model.change_month (rel_postion);
            tasks_model.change_month (rel_postion);
            selected_date = null;
            selection_changed (selected_date);

            /* creates a new Grid, when the Hdy.Carousel is on it's first/last page*/
            if (index + 1 == (int) carousel.get_n_pages ()) {
                events_model.change_month (1);
                tasks_model.change_month (1);
                var grid = create_grid ();
                grid.set_range (events_model.data_range, events_model.month_start);
                grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);
                carousel.append (grid);
                events_model.change_month (-1);
                tasks_model.change_month (-1);

            } else if (index == 0) {
                events_model.change_month (-1);
                tasks_model.change_month (-1);
                var grid = create_grid ();
                grid.set_range (events_model.data_range, events_model.month_start);
                grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);
                carousel.prepend (grid);
                events_model.change_month (1);
                tasks_model.change_month (1);
                position++;
            }
            label.label = events_model.month_start.format (_("%OB, %Y"));
        });
    }

    private DateTime.Widgets.Grid create_grid () {
        var grid = new DateTime.Widgets.Grid ();

        grid.on_event_add.connect ((date) => {
            show_date_in_maya (date);
            day_double_click ();
        });

        grid.selection_changed.connect ((date) => {
            selected_date = date;
            selection_changed (date);
        });

        return grid;
    }

    private void show_today (bool refresh = false) {
        showtoday = true;
        var today = Util.strip_time (new GLib.DateTime.now_local ());
        var start = Util.get_start_of_month (today);
        selected_date = today;
        if (start.equal (start_month) && !refresh) {
            position -= rel_postion;
            carousel.scroll_to (carousel.get_nth_page (position), true);
        } else {
            /*reset Carousel if center_child != the grid of the month of today*/
            for (var child = carousel.get_first_child (); child != null; child = carousel.get_first_child ()) {
                carousel.remove (child);
            }

            start_month = Util.get_start_of_month ();
            events_model.month_start = start_month;
            tasks_model.month_start = start_month;
            start_month_grid = create_grid ();
            start_month_grid.set_range (events_model.data_range, events_model.month_start);
            start_month_grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);

            events_model.change_month (-1);
            tasks_model.change_month (-1);
            var left_grid = create_grid ();
            left_grid.set_range (events_model.data_range, events_model.month_start);
            left_grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);

            events_model.change_month (2);
            tasks_model.change_month (2);
            var right_grid = create_grid ();
            right_grid.set_range (events_model.data_range, events_model.month_start);
            right_grid.update_weeks (events_model.data_range.first_dt, events_model.num_weeks);
            events_model.change_month (-1);
            tasks_model.change_month (-1);

            carousel.append (left_grid);
            carousel.append (start_month_grid);
            carousel.append (right_grid);
            carousel.scroll_to (start_month_grid, false);
            label.label = events_model.month_start.format (_("%OB, %Y"));

            position = 1;
            rel_postion = 0;
        }
    }

    // TODO: As far as maya supports it use the Dbus Activation feature to run the calendar-app.
    private void open_maya_with_options (GLib.DateTime? day_to_show, bool add_event = false) {
        day_to_show = day_to_show ?? new GLib.DateTime.now_local ();
        var command = "io.elementary.calendar";
        command += add_event ? " --add-event" : "";
        command += " --show-day %s".printf (day_to_show.format ("%F"));

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
            dialog.response.connect (dialog.destroy);
            dialog.present ();
        }
    }

    public void show_date_in_maya (GLib.DateTime date) {
        open_maya_with_options (date);
    }

    public void refresh () {
        show_today (true);
    }
}
