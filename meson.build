project(
    'datetime',
    'vala', 'c',
    version: '2.4.2',
    meson_version: '>= 0.58.0'
)

i18n = import('i18n')
gnome = import('gnome')

gettext_name = 'io.elementary.panel.' + meson.project_name()

prefix = get_option('prefix')
libdir = prefix / get_option('libdir')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_name), language:'c')
add_project_arguments(['--vapidir', meson.current_source_dir() / 'vapi'], language: 'vala')
add_project_arguments('-DG_LOG_DOMAIN="io.elementary.panel.datetime"', language:'c')

gresource = gnome.compile_resources(
    'gresource',
    'data' / 'datetime.gresource.xml',
    source_dir: 'data'
)

wingpanel_dep = dependency('wingpanel-9')
wingpanel_indicatorsdir = wingpanel_dep.get_variable('indicatorsdir', pkgconfig_define: ['libdir', libdir])

libecal_dep = dependency('libecal-2.0', required: false)
if libecal_dep.found()
    libical_dep = dependency('libical-glib')
    add_project_arguments('--define=E_CAL_2_0', language: 'vala')
    add_project_arguments('-DLIBICAL_GLIB_UNSTABLE_API=1', language: 'c')
else
    libecal_dep = dependency('libecal-1.2', version: '>=3.8.0')
    libical_dep = dependency('libical')
    add_project_arguments('--vapidir', meson.current_source_dir() / 'vapi', language: 'vala')
endif

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', prefix / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name() + '-indicator')
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

shared_module(
    meson.project_name(),
    gresource,
    config_file,
    'src/DateIterator.vala',
    'src/DateRange.vala',
    'src/Indicator.vala',
    'src/Widgets/ComponentRow.vala',
    'src/Widgets/PanelLabel.vala',
    'src/Widgets/calendar/CalendarModel.vala',
    'src/Widgets/calendar/CalendarView.vala',
    'src/Widgets/calendar/Grid.vala',
    'src/Widgets/calendar/GridDay.vala',
    'src/Widgets/calendar/Util.vala',
    'src/Services/TimeManager.vala',
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite-7', version: '>=7.6.0'),
        dependency('gtk4'),
        libecal_dep,
        dependency('libedataserver-1.2'),
        dependency('libadwaita-1'),
        libical_dep,
        wingpanel_dep,
    ],
    install: true,
    install_dir : wingpanel_indicatorsdir,
)

subdir('data')
subdir('po')

gnome.post_install(
    glib_compile_schemas: true
)
