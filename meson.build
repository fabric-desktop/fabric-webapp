project(
  'webapp',
  'vala', 'c',
  version: '2023-10-24'
)

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
  meson.get_compiler('vala').find_library('linux'),
  dependency('gtk4'),
  dependency('json-glib-1.0'),
  dependency('webkitgtk-6.0'),
  dependency('fabric-ui', fallback:['fabric-ui', 'fabric_ui_dep']),
]

assert(get_option('gio_modules') != '', 'gio_modules must be declared with appropriate paths.')

sources = []

# Add data for use at runtime
conf = configuration_data()
conf.set_quoted('GIO_MODULES', get_option('gio_modules'))
conf.set_quoted('VERSION', meson.project_version())
conf.set('bindir', join_paths(get_option('prefix'), 'bin'))

sources += configure_file(
  input: 'src/gio_modules.vala.in',
  output: 'gio_modules.vala',
  configuration: conf,
)

configure_file(
  input: 'fabric.applications.webapp.desktop.in',
  output: 'fabric.applications.webapp.desktop',
  configuration: conf,
  install_dir: join_paths(get_option('sysconfdir'), 'xdg/autostart')
)

# Call subdirs
subdir('src')
