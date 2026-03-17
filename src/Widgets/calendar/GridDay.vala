/*-
 * Copyright 2011–2020 elementary, Inc. (https://elementary.io)
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

/**
 * Represents a single day on the grid.
 */
public class DateTime.Widgets.GridDay : Granite.Bin {
    /*
     * Event emitted when the day is double clicked or the ENTER key is pressed.
     */
    public signal void on_event_add (GLib.DateTime date);

    public GLib.DateTime date { get; construct set; }

    private static Gtk.CssProvider provider;

    private Gee.HashMap<string, Gtk.Widget> component_dots;
    private Gtk.Box event_box;
    private Gtk.Label label;
    private bool valid_grab = false;

    public GridDay (GLib.DateTime date) {
        Object (date: date);
    }

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/GridDay.css");
    }

    construct {
        label = new Gtk.Label (null);

        label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        label.add_css_class (Granite.CssClass.CIRCULAR);

        event_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.CENTER,
            height_request = 6
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER

        };
        box.append (label);
        box.append (event_box);

        focusable = true;
        set_css_name ("grid-day");
        halign = Gtk.Align.CENTER;
        hexpand = true;
        get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        child = box;

        // Signals and handlers
        var click_gesture = new Gtk.GestureClick ();
        click_gesture.pressed.connect (on_button_press);
        add_controller (click_gesture);

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_press);
        add_controller (key_controller);

        bind_property ("date", label, "label", GLib.BindingFlags.SYNC_CREATE, (binding, from_value, ref to_value) => {
            unowned var new_date = (GLib.DateTime) from_value.get_boxed ();
            to_value.take_string (new_date.get_day_of_month ().to_string ());
            return true;
        }, null);

        component_dots = new Gee.HashMap<string, Gtk.Widget> ();
    }

    public void add_component_dot (E.Source source, ICal.Component ical) {
        if (component_dots.size >= 3) {
            return;
        }

        var component_uid = ical.get_uid ();
        if (!component_dots.has_key (component_uid)) {
            var event_dot = new Gtk.Image () {
                gicon = new ThemedIcon ("pager-checked-symbolic"),
                pixel_size = 6
            };
            event_dot.add_css_class (Granite.CssClass.ACCENT);
            event_dot.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            unowned E.SourceSelectable? source_selectable = null;
            if (source.has_extension (E.SOURCE_EXTENSION_TASK_LIST)) {
                source_selectable = (E.SourceSelectable?) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST);
            } else {
                source_selectable = (E.SourceSelectable?) source.get_extension (E.SOURCE_EXTENSION_CALENDAR);
            }
            Util.set_component_calendar_color (source_selectable, event_dot);

            component_dots[component_uid] = event_dot;

            event_box.append (event_dot);
        }
    }

    public void remove_component_dot (string component_uid) {
        var dot = component_dots[component_uid];
        if (dot != null) {
            dot.destroy ();
            component_dots.unset (component_uid);
        }
    }

    public void set_selected (bool selected) {
        if (selected) {
            set_state_flags (Gtk.StateFlags.SELECTED, true);
        } else {
            set_state_flags (Gtk.StateFlags.NORMAL, true);
        }
    }

    public void grab_focus_force () {
        valid_grab = true;
        grab_focus ();
    }

    public override bool grab_focus () {
        if (valid_grab) {
            base.grab_focus ();
            valid_grab = false;
            return true;
        }

        return false;
    }

    public void sensitive_container (bool sens) {
        label.sensitive = sens;
        event_box.sensitive = sens;
    }

    private void on_button_press (int n_press) {
        if (n_press == 2) {
            on_event_add (date);
        }
        valid_grab = true;
        grab_focus ();
    }

    private bool on_key_press (uint keyval) {
        if (keyval == Gdk.keyval_from_name ("Return") ) {
            on_event_add (date);
            return true;
        }

        return false;
    }
}
