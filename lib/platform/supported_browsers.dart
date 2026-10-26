// The browsers the web app is tested on (specs/008 data-model › Supported browser list, FR-003):
// the current and previous major version of each. web/index.html names the same browsers on its
// unsupported-browser page; tool/web_deploy.mjs refuses a build where the two differ.

/// One supported browser and where it is tested.
typedef SupportedBrowser = ({String name, List<String> desktop, List<String> phone});

const supportedBrowsers = <SupportedBrowser>[
  (name: 'Chrome', desktop: ['Windows', 'macOS'], phone: ['Android']),
  (name: 'Edge', desktop: ['Windows'], phone: []),
  (name: 'Firefox', desktop: ['Windows', 'macOS'], phone: ['Android']),
  (name: 'Safari', desktop: ['macOS'], phone: ['iOS']),
];

/// "Chrome, Edge, Firefox, Safari", for messages in either language (browser names are not
/// translated).
String get supportedBrowserNames => supportedBrowsers.map((b) => b.name).join(', ');
