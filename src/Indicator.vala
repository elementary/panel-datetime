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
    public static GLib.Settings settings;

    private Widgets.PanelLabel panel_label;
    private Gtk.Grid main_grid;
    private Widgets.CalendarView calendar;
    private Gtk.ListBox component_listbox;
    private uint update_components_idle_source = 0;

    public Indicator () {
        Object (
            code_name: Wingpanel.Indicator.DATETIME
        );
    }

    static construct {
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

        settings = new GLib.Settings ("io.elementary.desktop.wingpanel.datetime");
    }

    construct {
        visible = true;
    }

    ~Indicator () {
        ICal.Object.free_global_objects ();
    }

    public override Gtk.Widget get_display_widget () {
        if (panel_label == null) {
            panel_label = new Widgets.PanelLabel () {
                tooltip_markup = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Middle-click to open Calendar"))
            };
        }

        return panel_label;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            calendar = new Widgets.CalendarView () {
                margin_bottom = 6
            };

            var placeholder_label = new Gtk.Label (_("No events this day")) {
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD,
                margin_start = 12,
                margin_end = 12,
                max_width_chars = 20,
                justify = Gtk.Justification.CENTER
            };
            placeholder_label.add_css_class (Granite.CssClass.DIM);
            placeholder_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

            component_listbox = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            component_listbox.set_header_func (header_update_func);
            component_listbox.set_placeholder (placeholder_label);
            component_listbox.set_sort_func (sort_function);

            var scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                child = component_listbox
            };

            var settings_button = new Wingpanel.PopoverMenuItem.with_text (_("Date & Time Settings…"));

            var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
                margin_bottom = 3,
                margin_top = 3
            };

            main_grid = new Gtk.Grid () {
                margin_top = 12
            };
            main_grid.attach (calendar, 0, 0);
            main_grid.attach (scrolled_window, 1, 0);
            main_grid.attach (sep, 0, 2, 2, 1);
            main_grid.attach (settings_button, 0, 3, 2, 1);

            var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            size_group.add_widget (calendar);
            size_group.add_widget (component_listbox);

            calendar.day_double_click.connect (() => {
                close ();
            });

            calendar.selection_changed.connect ((date) => {
                idle_update_components ();
            });

            component_listbox.row_activated.connect ((row) => {
                var component_row = (DateTime.ComponentRow) row;

                if (component_row.source_selectable is E.SourceCalendar) {
                    calendar.show_date_in_maya (((DateTime.ComponentRow) row).date);
                    close ();
                } else if (component_row.source_selectable is E.SourceTaskList) {
                    var appinfo = new DesktopAppInfo ("io.elementary.tasks.desktop");
                    try {
                        appinfo.launch (null, null);
                    } catch (Error e) {
                        var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                            _("Unable To launch Tasks"),
                            _("The program \"io.elementary.tasks\" may not be installed"),
                            "dialog-error"
                        );
                        dialog.show_error_details (e.message);
                        dialog.response.connect ((_dialog, response) => _dialog.destroy ());
                        dialog.present ();
                    }
                    close ();
                }
            });

            settings_button.clicked.connect (() => {
                try {
                    AppInfo.launch_default_for_uri ("settings://time", null);
                } catch (Error e) {
                    warning ("Could not open time and date settings: %s", e.message);
                }
            });
        }

        return main_grid;
    }

    private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        var row = (DateTime.ComponentRow) lbrow;
        if (lbbefore != null) {
            var before = (DateTime.ComponentRow) lbbefore;
            if (row.is_allday == before.is_allday) {
                row.set_header (null);
                return;
            }

            if (row.is_allday != before.is_allday) {
                var header_label = new Granite.HeaderLabel (_("During the Day"));
                header_label.margin_start = header_label.margin_end = 6;

                row.set_header (header_label);
                return;
            }
        } else {
            if (row.is_allday) {
                var allday_header = new Granite.HeaderLabel (_("All Day"));
                allday_header.margin_start = allday_header.margin_end = 6;

                row.set_header (allday_header);
            }
            return;
        }
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
        var e1 = (ComponentRow) child1;
        var e2 = (ComponentRow) child2;

        if (e1.start_time.compare (e2.start_time) != 0) {
            return e1.start_time.compare (e2.start_time);
        }

        // If they have the same date, sort them wholeday first
        if (e1.is_allday) {
            return -1;
        } else if (e2.is_allday) {
            return 1;
        }

        return 0;
    }

    private void update_components_model (E.Source source, Gee.Collection<ECal.Component> events) {
        idle_update_components ();
    }

    private void idle_update_components () {
        if (update_components_idle_source > 0) {
            GLib.Source.remove (update_components_idle_source);
        }

        update_components_idle_source = GLib.Idle.add (update_components);
    }

    private bool update_components () {
        component_listbox.remove_all ();

        if (calendar.selected_date == null) {
            update_components_idle_source = 0;
            return GLib.Source.REMOVE;
        }

        var date = calendar.selected_date;

        var events_model = Widgets.CalendarModel.get_default (ECal.ClientSourceType.EVENTS);
        var tasks_model = Widgets.CalendarModel.get_default (ECal.ClientSourceType.TASKS);

        var components_on_day = new Gee.TreeMap<string, DateTime.ComponentRow> ();

        events_model.source_components.@foreach ((source, component_map) => {
            foreach (var comp in component_map.get_values ()) {
                if (Util.calcomp_is_on_day (comp, date)) {
                    unowned ICal.Component ical = comp.get_icalcomponent ();
                    var component_uid = ical.get_uid ();
                    if (!components_on_day.has_key (component_uid)) {
                        components_on_day[component_uid] = new DateTime.ComponentRow (date, ical, source);

                        component_listbox.append (components_on_day[component_uid]);
                    }
                }
            }
        });

        tasks_model.source_components.@foreach ((source, component_map) => {
            foreach (var comp in component_map.get_values ()) {
                if (Util.calcomp_is_on_day (comp, date)) {
                    unowned ICal.Component ical = comp.get_icalcomponent ();
                    var component_uid = ical.get_uid ();
                    if (!components_on_day.has_key (component_uid)) {
                        components_on_day[component_uid] = new DateTime.ComponentRow (date, ical, source);

                        component_listbox.append (components_on_day[component_uid]);
                    }
                }
            }
        });

        update_components_idle_source = 0;
        return GLib.Source.REMOVE;
    }

    public override void opened () {
        var events_model = Widgets.CalendarModel.get_default (ECal.ClientSourceType.EVENTS);
        var tasks_model = Widgets.CalendarModel.get_default (ECal.ClientSourceType.TASKS);

        events_model.components_added.connect (update_components_model);
        tasks_model.components_added.connect (update_components_model);

        events_model.components_updated.connect (update_components_model);
        tasks_model.components_updated.connect (update_components_model);

        events_model.components_removed.connect (update_components_model);
        tasks_model.components_removed.connect (update_components_model);

        calendar.refresh ();
    }

    public override void closed () {
        var events_model = Widgets.CalendarModel.get_default (ECal.ClientSourceType.EVENTS);
        var tasks_model = Widgets.CalendarModel.get_default (ECal.ClientSourceType.TASKS);

        events_model.components_added.disconnect (update_components_model);
        tasks_model.components_added.disconnect (update_components_model);

        events_model.components_updated.disconnect (update_components_model);
        tasks_model.components_updated.disconnect (update_components_model);

        events_model.components_removed.disconnect (update_components_model);
        tasks_model.components_removed.disconnect (update_components_model);
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating DateTime Indicator");

    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        debug ("Wingpanel is not in session, not loading DateTime");
        return null;
    }

    var indicator = new DateTime.Indicator ();

    return indicator;
}
