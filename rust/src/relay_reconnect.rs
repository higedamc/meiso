//! Relay pool reconnection that cannot kill the pool (issue #188).
//!
//! `MeisoNostrClient::reconnect*` used to call `Client::disconnect()` and then
//! `Client::connect()` right away. In nostr-sdk 0.37 `disconnect()` only *requests* loop
//! termination and `connect()` skips every relay that is not yet `Terminated`, so the relay
//! ended `Terminated` with no loop left to retry. Only building a new client (Settings →
//! Save and Connect) recovered. See `RESEARCH/MEISO_RELAY_RECONNECT_RACE.md` in the team
//! workspace for the measurements.
//!
//! Waiting for `Terminated` before calling `connect()` is not safe either: the connection
//! loop stores `Terminated` *before* it clears its `running` flag, and `connect()` on a relay
//! whose previous loop is still flagged as running sets `Pending`, spawns nothing, and waits
//! forever. `Pending` is not a state `connect()` will ever touch again.
//!
//! This module therefore never calls `connect()` on a `Relay` that has already run a loop.
//! Per relay, based on its current status:
//! - `Connected`: nothing to do.
//! - `Connecting` / `Pending`: an attempt is in flight. Leave it alone and give it until the
//!   deadline to settle. (Tor relays legitimately take seconds here.)
//! - `Disconnected` (loop asleep in backoff, 10 s to 10 min) and `Terminated` (no loop):
//!   remove the relay from the pool and add it back. That yields a fresh `Relay` object with
//!   no shared `running` flag, which inherits the pool's subscriptions
//!   (`RelayPool::add_relay(..., inherit_pool_subscriptions = true, ...)`), so live receive
//!   resumes on the first connection. Then connect it with a bounded wait.
//! - `Initialized`: never had a loop, so `connect()` is safe.
//!
//! Every wait is bounded by the caller's duration and the function never fails: whatever
//! happened, the caller gets the number of relays that are `Connected` right now.

use nostr_sdk::prelude::*;
use std::time::Duration;
use tokio::time::{sleep, timeout, Instant};

/// Poll interval while waiting for in-flight connection attempts to settle.
const POLL: Duration = Duration::from_millis(25);

/// Upper bound on the whole reconnect, whatever the caller asks for.
const MAX_WAIT: Duration = Duration::from_secs(30);

/// Result of [`reconnect_relays`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub(crate) struct ReconnectReport {
    /// Relays whose status is `Connected` when the function returns.
    pub connected: u32,
    /// Relays in the pool when the function returns.
    pub total: u32,
    /// Relays that were rebuilt (`Disconnected` / `Terminated` at entry).
    pub replaced: u32,
}

/// Bring every relay of `client` back to `Connected` if it can be done within `wait`.
///
/// Never returns an error and never leaves a relay in a state nothing will retry. See the
/// module documentation for the per-status policy.
pub(crate) async fn reconnect_relays(client: &Client, wait: Duration) -> ReconnectReport {
    // Clamp: at least 1 s so a connect has a chance, at most MAX_WAIT so a caller can never
    // park the UI (or overflow `Instant + Duration`) with a huge timeout.
    let wait = wait.clamp(Duration::from_secs(1), MAX_WAIT);
    let deadline = Instant::now() + wait;
    let mut replaced = 0u32;
    let mut attempts = Vec::new();

    for (url, relay) in client.relays().await {
        match relay.status() {
            RelayStatus::Connected | RelayStatus::Connecting | RelayStatus::Pending => {}
            RelayStatus::Initialized => attempts.push(spawn_connect(relay, wait)),
            RelayStatus::Disconnected | RelayStatus::Terminated => {
                match replace_relay(client, &url).await {
                    Ok(fresh) => {
                        replaced += 1;
                        attempts.push(spawn_connect(fresh, wait));
                    }
                    Err(e) => dev_eprintln!("⚠️ Could not rebuild relay {}: {}", url, e),
                }
            }
        }
    }

    // Each attempt is already bounded by the websocket connect timeout, but the status wait
    // inside `Relay::connect(Some(_))` is not, so bound it again from the outside.
    for attempt in attempts {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if timeout(remaining, attempt).await.is_err() {
            dev_eprintln!("⚠️ Relay connect attempt did not settle within {:?}", wait);
        }
    }

    // Give attempts that were already in flight at entry until the deadline to settle.
    loop {
        let relays = client.relays().await;
        let in_flight = relays
            .values()
            .any(|r| matches!(r.status(), RelayStatus::Connecting | RelayStatus::Pending));
        if !in_flight || Instant::now() >= deadline {
            let connected = relays
                .values()
                .filter(|r| r.status() == RelayStatus::Connected)
                .count() as u32;
            return ReconnectReport {
                connected,
                total: relays.len() as u32,
                replaced,
            };
        }
        sleep(POLL).await;
    }
}

fn spawn_connect(relay: Relay, wait: Duration) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move { relay.connect(Some(wait)).await })
}

/// Replace `url` in the pool with a fresh `Relay` and return the new handle.
async fn replace_relay(client: &Client, url: &RelayUrl) -> anyhow::Result<Relay> {
    client.remove_relay(url.clone()).await?;
    // `remove_relay` keeps a GOSSIP-flagged relay (only strips its flags); then `add_relay`
    // returns false and `relay()` would hand back the stale handle. Never reconnect that one.
    if !client.add_relay(url.clone()).await? {
        anyhow::bail!("relay was kept by the pool (gossip flags); not rebuilt");
    }
    Ok(client.relay(url.clone()).await?)
}

#[cfg(test)]
mod tests {
    //! These tests run a real relay (`nak serve`, in memory) as a child process so they can
    //! reproduce the field case: the relay goes away, the SDK marks the relay `Disconnected`
    //! and backs off, the relay comes back, and the app's reconnect must bring both send and
    //! live receive back without waiting for the SDK's own retry.
    //!
    //! `nak` is looked up via `MEISO_NAK_BIN` or on `PATH`. Without it the nak-backed tests
    //! print a skip notice and return, unless `MEISO_RELAY_TESTS_REQUIRED` is set, in which
    //! case they fail. CI sets that variable so a skip can never pass as green there.

    use super::*;
    use std::net::TcpListener;
    use std::process::{Child, Command, Stdio};

    const NAK_BIN_ENV: &str = "MEISO_NAK_BIN";
    const REQUIRED_ENV: &str = "MEISO_RELAY_TESTS_REQUIRED";

    fn free_port() -> u16 {
        TcpListener::bind("127.0.0.1:0")
            .expect("bind ephemeral port")
            .local_addr()
            .expect("local addr")
            .port()
    }

    /// Wait until `port` accepts a TCP connection. Fails fast, with nak's exit status and
    /// stderr, if the child exits first; a child that never listens is a harness bug, not a
    /// reconnect bug, and must not look like one.
    async fn wait_listening(child: &mut Child, port: u16, stderr_path: &std::path::Path) {
        let t = Instant::now();
        loop {
            if tokio::net::TcpStream::connect(("127.0.0.1", port))
                .await
                .is_ok()
            {
                return;
            }
            if let Ok(Some(status)) = child.try_wait() {
                let stderr = std::fs::read_to_string(stderr_path).unwrap_or_default();
                panic!("nak exited before listening on {port}: {status}; stderr: {stderr}");
            }
            assert!(
                t.elapsed() < Duration::from_secs(10),
                "nak did not start listening on {port} within 10 s"
            );
            sleep(Duration::from_millis(50)).await;
        }
    }

    /// An in-memory `nak serve` relay owned by the test. Killed on drop.
    struct NakRelay {
        child: Option<Child>,
        port: u16,
        stderr_path: std::path::PathBuf,
    }

    impl NakRelay {
        /// `None` means nak is not available and the test should return early (skip).
        async fn start() -> Option<Self> {
            let port = free_port();
            let mut relay = Self {
                child: None,
                port,
                stderr_path: std::env::temp_dir()
                    .join(format!("meiso-nak-{}-{port}.stderr", std::process::id())),
            };
            relay.spawn().await.then_some(relay)
        }

        async fn spawn(&mut self) -> bool {
            let bin = std::env::var(NAK_BIN_ENV).unwrap_or_else(|_| "nak".to_string());
            // Restart reuses the path; drop the previous file (a symlink is removed, not
            // followed). create_new then refuses anything that appears in between.
            let _ = std::fs::remove_file(&self.stderr_path);
            let stderr = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&self.stderr_path)
                .expect("nak stderr file");
            let spawned = Command::new(&bin)
                .args([
                    "serve",
                    "--hostname",
                    "127.0.0.1",
                    "--port",
                    &self.port.to_string(),
                ])
                // nak reads stdin when it is not a terminal and blocks before binding its
                // port if that stdin is an open pipe (observed under `cargo test` here);
                // an explicit null stdin keeps the relay start deterministic in CI.
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::from(stderr))
                .spawn();
            match spawned {
                Ok(child) => {
                    // Store first so a panic inside `wait_listening` still kills the child.
                    let child = self.child.insert(child);
                    wait_listening(child, self.port, &self.stderr_path).await;
                    true
                }
                Err(e) => {
                    if std::env::var_os(REQUIRED_ENV).is_some() {
                        panic!("{REQUIRED_ENV} is set but `{bin}` could not be started: {e}");
                    }
                    eprintln!(
                        "SKIP: `{bin}` not available ({e}); install nak or set {NAK_BIN_ENV} to run this test"
                    );
                    false
                }
            }
        }

        fn url(&self) -> String {
            format!("ws://127.0.0.1:{}", self.port)
        }

        fn kill(&mut self) {
            if let Some(mut child) = self.child.take() {
                let _ = child.kill();
                let _ = child.wait();
            }
        }

        /// Simulate the relay coming back on the same URL.
        async fn restart(&mut self) {
            self.kill();
            assert!(self.spawn().await, "nak restart failed");
        }
    }

    impl Drop for NakRelay {
        fn drop(&mut self) {
            self.kill();
            let _ = std::fs::remove_file(&self.stderr_path);
        }
    }

    async fn connected_client(url: &str, keys: Keys) -> Client {
        let client = Client::new(keys);
        client.add_relay(url).await.expect("add relay");
        client.connect_with_timeout(Duration::from_secs(5)).await;
        let relay = client.relay(url).await.expect("relay handle");
        assert_eq!(
            relay.status(),
            RelayStatus::Connected,
            "fixture client must connect"
        );
        client
    }

    async fn wait_status(relay: &Relay, want: RelayStatus, bound: Duration) -> bool {
        let t = Instant::now();
        while t.elapsed() < bound {
            if relay.status() == want {
                return true;
            }
            sleep(Duration::from_millis(20)).await;
        }
        false
    }

    /// Publish a text note from a fresh client holding `publisher` and assert that
    /// `receiver`'s subscription delivers that exact event live.
    async fn assert_live_receive(receiver: &Client, url: &str, publisher: &Keys, tag: &str) {
        let publisher_client = connected_client(url, publisher.clone()).await;
        let mut notifications = receiver.notifications();
        let out = publisher_client
            .send_event_builder(EventBuilder::text_note(format!("live receive {tag}")))
            .await
            .expect("publish");
        assert_eq!(
            out.success.len(),
            1,
            "publisher must reach the relay ({tag})"
        );
        let wanted = out.val;
        let delivered = timeout(Duration::from_secs(5), async {
            loop {
                match notifications.recv().await {
                    Ok(RelayPoolNotification::Event { event, .. }) if event.id == wanted => {
                        break true
                    }
                    Ok(_) => continue,
                    Err(_) => break false,
                }
            }
        })
        .await;
        assert_eq!(
            delivered,
            Ok(true),
            "receiver did not get the live event ({tag}); subscription is dead"
        );
        let _ = publisher_client.shutdown().await;
    }

    async fn subscribe_to_author(client: &Client, author: PublicKey) {
        client
            .subscribe(
                vec![Filter::new().author(author).kind(Kind::TextNote)],
                None,
            )
            .await
            .expect("subscribe");
    }

    /// Field case from the 2026-10-08 acceptance run: the socket drops, the SDK parks the
    /// relay in `Disconnected` and backs off, the relay is reachable again, and the app's
    /// reconnect must restore send *and* live receive without waiting out the backoff.
    ///
    /// Negative control: with the old disconnect-then-connect shape this fails at
    /// `report.connected` (0, relay `Terminated`).
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn relay_outage_then_reconnect_restores_send_and_live_receive() {
        let Some(mut nak) = NakRelay::start().await else {
            return;
        };
        let url = nak.url();
        let publisher = Keys::generate();
        let receiver = connected_client(&url, Keys::generate()).await;
        subscribe_to_author(&receiver, publisher.public_key()).await;
        assert_live_receive(&receiver, &url, &publisher, "before outage").await;

        nak.kill();
        let relay = receiver.relay(&url).await.unwrap();
        assert!(
            wait_status(&relay, RelayStatus::Disconnected, Duration::from_secs(10)).await,
            "SDK must notice the closed socket"
        );
        nak.restart().await;

        let t = Instant::now();
        let report = reconnect_relays(&receiver, Duration::from_secs(3)).await;
        eprintln!("reconnect after outage took {:?}: {report:?}", t.elapsed());
        assert_eq!(report.connected, 1, "{report:?}");
        assert_eq!(report.replaced, 1, "{report:?}");
        assert!(
            t.elapsed() < Duration::from_secs(5),
            "reconnect took {:?}; it must not wait for the SDK's own 10 s retry",
            t.elapsed()
        );
        let relay = receiver.relay(&url).await.unwrap();
        assert_eq!(relay.status(), RelayStatus::Connected);

        assert_live_receive(&receiver, &url, &publisher, "after reconnect").await;
        let out = receiver
            .send_event_builder(EventBuilder::text_note("send after reconnect"))
            .await
            .expect("send");
        assert_eq!(
            out.success.len(),
            1,
            "send must reach the relay after reconnect"
        );
    }

    /// Calling reconnect on a healthy pool must be harmless: nothing is rebuilt and the
    /// existing subscription keeps delivering.
    ///
    /// Negative control: the old shape terminates the relay here (0 connected).
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn reconnect_while_connected_keeps_live_receive() {
        let Some(nak) = NakRelay::start().await else {
            return;
        };
        let url = nak.url();
        let publisher = Keys::generate();
        let receiver = connected_client(&url, Keys::generate()).await;
        subscribe_to_author(&receiver, publisher.public_key()).await;
        assert_live_receive(&receiver, &url, &publisher, "before reconnect").await;

        let report = reconnect_relays(&receiver, Duration::from_secs(3)).await;
        assert_eq!(
            report,
            ReconnectReport {
                connected: 1,
                total: 1,
                replaced: 0
            }
        );
        let relay = receiver.relay(&url).await.unwrap();
        assert_eq!(relay.status(), RelayStatus::Connected);
        assert_live_receive(&receiver, &url, &publisher, "after reconnect").await;
    }

    /// The #188 state: the relay has been terminated (no loop left). Reconnect right after
    /// the status flips, with no grace period, must return within the bound and end
    /// `Connected` with the subscription alive. The old `running` flag of the terminated loop
    /// is irrelevant because the relay is rebuilt rather than reused.
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn reconnect_from_terminated_without_grace_recovers() {
        let Some(nak) = NakRelay::start().await else {
            return;
        };
        let url = nak.url();
        let publisher = Keys::generate();
        let receiver = connected_client(&url, Keys::generate()).await;
        subscribe_to_author(&receiver, publisher.public_key()).await;

        let relay = receiver.relay(&url).await.unwrap();
        relay.disconnect().expect("request terminate");
        assert!(
            wait_status(&relay, RelayStatus::Terminated, Duration::from_secs(5)).await,
            "relay must terminate"
        );

        let t = Instant::now();
        let report = reconnect_relays(&receiver, Duration::from_secs(3)).await;
        assert!(
            t.elapsed() < Duration::from_secs(5),
            "took {:?}",
            t.elapsed()
        );
        assert_eq!(report.connected, 1, "{report:?}");
        assert_eq!(report.replaced, 1, "{report:?}");
        assert_live_receive(&receiver, &url, &publisher, "after terminated").await;
    }

    /// A relay whose connection attempt is still in flight (TCP accepted, websocket
    /// handshake never answered) must be left alone: not rebuilt, and the call must still
    /// return at the deadline with an honest count. No nak needed for this one.
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn reconnect_leaves_in_flight_attempt_alone_and_returns_at_deadline() {
        // Bound but never accept: the TCP connect succeeds, the websocket upgrade never does.
        let black_hole = TcpListener::bind("127.0.0.1:0").expect("bind");
        let url = format!("ws://127.0.0.1:{}", black_hole.local_addr().unwrap().port());

        let client = Client::new(Keys::generate());
        client.add_relay(&url).await.expect("add relay");
        client.connect().await; // spawns the loop with a 60 s connect timeout, returns at once
        let relay = client.relay(&url).await.unwrap();
        assert!(
            wait_status(&relay, RelayStatus::Connecting, Duration::from_secs(5)).await,
            "relay should be mid-attempt, got {}",
            relay.status()
        );

        let t = Instant::now();
        let report = reconnect_relays(&client, Duration::from_secs(1)).await;
        assert!(
            t.elapsed() >= Duration::from_secs(1) && t.elapsed() < Duration::from_secs(3),
            "must return at the deadline, took {:?}",
            t.elapsed()
        );
        assert_eq!(
            report,
            ReconnectReport {
                connected: 0,
                total: 1,
                replaced: 0
            }
        );
        assert_eq!(
            relay.status(),
            RelayStatus::Connecting,
            "in-flight attempt was disturbed"
        );
        drop(black_hole);
    }
}
