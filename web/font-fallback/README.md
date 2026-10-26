Fallback fonts for the web app (specs/008 research R1), served from get.mthani.app instead of
fonts.gstatic.com so no reader's request reaches Google (FR-027).

Flutter's web engine fetches a fallback font only for a character none of the bundled fonts
has, at `font-fallback/<family>/<version>/<file>.woff2` (web/flutter_bootstrap.js sets the
base). Each file here is an unmodified copy of Google Fonts' file at the same path under
https://fonts.gstatic.com/s/, licensed under the SIL Open Font License 1.1.

When spike S1's network log, or a reader, shows a request for a file that is missing here,
download it from the same path on fonts.gstatic.com into the same path here.

- notosansarabic/v28: Noto Sans Arabic (OFL 1.1), needed by the reader.
