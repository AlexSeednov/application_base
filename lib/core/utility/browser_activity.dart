// A visible browser tab can be unfocused. Native applications get activity
// from their lifecycle instead.
export 'browser_activity_stub.dart'
    if (dart.library.js_interop) 'browser_activity_web.dart';
