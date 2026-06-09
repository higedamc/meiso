// Meiso: optional WebSocket User-Agent for relay connections (issue #130).
// Upstream async-wsocket does not expose custom headers; this fork adds a process-global setter.

use std::sync::Mutex;

static OPTIONAL_USER_AGENT: Mutex<Option<String>> = Mutex::new(None);

/// Set or clear the `User-Agent` header for subsequent WebSocket handshakes (native targets).
/// Pass `None` to omit the header (default).
pub fn set_optional_websocket_user_agent(agent: Option<String>) {
    let mut g = OPTIONAL_USER_AGENT.lock().expect("user agent mutex poisoned");
    *g = agent;
}

pub(crate) fn get() -> Option<String> {
    OPTIONAL_USER_AGENT
        .lock()
        .expect("user agent mutex poisoned")
        .clone()
}
