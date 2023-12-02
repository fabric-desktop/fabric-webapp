namespace Fabric.Applications.Webapp {
	class Configuration : Object {
		public string id { get; set; default = ""; }
		public string title { get; set; default = "%title%"; }
		public string url { get; set; default = "about:blank"; }
		public bool cookies { get; set; default = false; }
		public List<string> allowed_uri_patterns;

		construct {
			allowed_uri_patterns = new List<string>();
		}

		public Configuration.from_json_string(string json_string) {
			try {
				Json.Parser parser = new Json.Parser();
				parser.load_from_data(json_string);

				this.from_json_node(parser.get_root());
			} catch (Error e) {
				stderr.printf("Error: %s", e.message);
				Process.exit(1);
			}
		}

		private void from_json_node(Json.Node json) {
			var cfg = json.get_object();
			id = cfg.get_string_member("id");
			title = cfg.get_string_member("title");
			url = cfg.get_string_member("url");
			cookies = cfg.get_boolean_member("cookies");
			cfg.get_array_member("allowed_uri_patterns").foreach_element((_array, _index, el) => {
				allowed_uri_patterns.append(el.get_string());
			});

			if (title == "" || title == null) {
				title = "%title%";
			}
		}

		public string title_for(string page_title) {
			return title.replace("%title%", page_title).strip();
		}
	}

	class WebAppPage : Fabric.UI.Page {
		private WebKit.WebView webview;
		public static Configuration config { get; set; }
		public signal void title_change(string new_title);
		public signal void favicon_change(Gdk.Texture new_icon);

		construct {
			var webdata_dir = "/var/empty";
			var cookie_file = Path.build_filename(Fabric.UI.Application.get_data_dir(), "cookies");

			if (config.cookies) {
				webdata_dir = Path.build_filename(Fabric.UI.Application.get_data_dir(), "data");
				DirUtils.create_with_parents(webdata_dir, 0700);
			}

			var network_session = new WebKit.NetworkSession(webdata_dir, Fabric.UI.Application.get_cache_dir());
			network_session.get_website_data_manager().set_favicons_enabled(true);
			// Workaround for AFAIUI has_construct_function=false on WebView, and needing
			// to use GObject-style construction... *sigh*
			webview = (WebKit.WebView)Object.@new(
				typeof (WebKit.WebView)
				, "network-session", network_session
			);
			webview.hexpand = true;
			webview.vexpand = true;
			append(webview);
			webview.load_uri(config.url);
			webview.zoom_level = Fabric.UI.Application.scale;

			if (config.cookies) {
				var cookie_manager = webview.network_session.get_cookie_manager();
				DirUtils.create_with_parents(Fabric.UI.Application.get_data_dir(), 0700);
				cookie_manager.set_persistent_storage(cookie_file, WebKit.CookiePersistentStorage.TEXT);
			}

			var hotkeys = new Gtk.EventControllerKey();
			hotkeys.key_pressed.connect((keyval, keycode, state) => {
				switch (keyval) {
					case Fabric.UI.Keys.Backspace:
					case Fabric.UI.Keys.XF86Back:
						webview.go_back();
						break;
				}
			});
			this.add_controller(hotkeys);

			webview.notify["title"].connect(() => {
				title_change(webview.title);
			});

			webview.notify["favicon"].connect(() => {
				favicon_change(webview.favicon);
			});

			webview.context_menu.connect(() => {
				return true;
			});

			webview.decide_policy.connect((decision, type) => {
				switch (type) {
					case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
						break;
					case WebKit.PolicyDecisionType.RESPONSE:
						WebKit.ResponsePolicyDecision response_decision = (WebKit.ResponsePolicyDecision)decision;
						// For now only filter responses from the main frame
						if (response_decision.is_main_frame_main_resource()) {
							var uri = response_decision.get_request().uri;
							if (is_allowable_uri(uri)) {
								debug("Navigation allowed to: '%s'", uri);
								decision.use();
							}
							else {
								// TODO config: allow disabling opening external URIs (by list of pattern?)
								AppInfo.launch_default_for_uri_async.begin(uri, null, null);
								debug("Navigation internally deined to: '%s'", uri);
								decision.ignore();
							}
						}
						else {
							// This could be used to harden specific webapps with an additional Blocklist/Allowlist otherwise later.
						}
						break;
					case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
						WebKit.NavigationPolicyDecision navigation_decision = (WebKit.NavigationPolicyDecision)decision;
						var uri = navigation_decision.navigation_action.get_request().uri;
						AppInfo.launch_default_for_uri_async.begin(uri, null, null);
						debug("New window opened for: '%s'", uri);
						decision.ignore();
						break;
				}
			});
		}
		public bool is_allowable_uri(string uri) {
			foreach (string pattern in config.allowed_uri_patterns) {
				if (Regex.match_simple(pattern, uri)) {
					return true;
				}
			}

			return false;
		}
	}

	class Application : Fabric.UI.Application {
		private Configuration config;
		private Fabric.UI.Window _window;
		public Fabric.UI.Window window {
			get { return _window; }
		}

		public Application(string[] args) {
			// TODO: better args parsing
			if (args.length != 2) {
				stderr.printf("Usage: webapp <config>\n");
				Process.exit(1);
			}
			if (!Regex.match_simple("/", args[1])) {
				stderr.printf("As of now, only qualified path names can be used.\n");
				Process.exit(2);
			}

			string contents;
			FileUtils.get_contents(args[1], out contents);
			config = new Configuration.from_json_string(contents);

			if (config.id == "") {
				stderr.printf("`config.id` not set in config.\n");
				Process.exit(1);
			}
			if (config.url == "") {
				stderr.printf("`config.url` not set in config.\n");
				Process.exit(1);
			}
			if (config.allowed_uri_patterns.length() == 0) {
				stderr.printf("`config.allowed_uri_patterns` not set in config or no patterns provided.\n");
				Process.exit(1);
			}

			application_id = "fabric.applications.webapp.%s".printf(config.id);
			Environment.set_prgname("webapp[%s]".printf(config.id));
		}

		protected override void activate() {
			WebAppPage.config = config;
			var page = new WebAppPage();
			Fabric.UI.PagesContainer.instance.push(page);
			page.title_change.connect((new_title) => {
				window.title = config.title_for(new_title);
			});
			page.favicon_change.connect((new_icon) => {
				if (new_icon != null) {
					window.set_icon_from_texture(new_icon);
				}
			});
			_window = new Fabric.UI.PagedWindow() {
				application = this,
				title = config.title_for(""),
			};
			_window.present();
		}
	}

	public static int main(string[] args) {
		Environment.set_variable("GIO_EXTRA_MODULES", GIO_MODULES, true);

		return (new Application(args)).run();
	}
}
