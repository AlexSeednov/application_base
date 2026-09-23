/// Non-web branch of `UrlLauncher.downloadLink`: outside a browser there is
/// no page to hand a download to. Nothing starts here, and the link goes on
/// to a plain launch.
bool downloadViaAnchor(String link) => false;
