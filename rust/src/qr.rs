//! QR decoding for the member picker (issue #245).
//!
//! Pure-Rust `rqrr` replaces Google ML Kit, so the APK carries no Play
//! Services, Firebase, or Google telemetry code. Dart hands over the Y (luma)
//! plane of a YUV420 camera frame; on Android the row stride can exceed the
//! width, so callers pass `bytes_per_row` separately.

use rqrr::PreparedImage;

/// Decode every QR code visible in one greyscale frame.
///
/// Returns the decoded payloads in detection order, or an empty vector when
/// nothing decodes or the buffer geometry is inconsistent. This runs on every
/// camera frame, so malformed geometry must never panic.
pub fn decode_qr_luma(luma: Vec<u8>, width: u32, height: u32, bytes_per_row: u32) -> Vec<String> {
    let (w, h, stride) = (width as usize, height as usize, bytes_per_row as usize);
    // Bytes the last row must reach: stride * (h - 1) + w. Checked arithmetic
    // keeps the bound honest on 32-bit ABIs (armeabi-v7a), where the plain
    // expression could wrap and let an out-of-range index through; h == 0
    // falls out as None via checked_sub.
    let needed = h
        .checked_sub(1)
        .and_then(|rows| stride.checked_mul(rows))
        .and_then(|n| n.checked_add(w));
    if w == 0 || stride < w || needed.is_none_or(|n| luma.len() < n) {
        return Vec::new();
    }
    let mut img = PreparedImage::prepare_from_greyscale(w, h, |x, y| luma[y * stride + x]);
    img.detect_grids()
        .iter()
        .filter_map(|grid| grid.decode().ok().map(|(_, text)| text))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use qrcode::{Color, QrCode};

    const NPUB: &str = "nostr:npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg";
    const SCALE: usize = 4;
    const QUIET: usize = 4;

    /// Render `payload` as a QR into a luma buffer with `pad` extra stride
    /// bytes per row. Returns (buffer, width, height, bytes_per_row).
    fn render(payload: &str, pad: usize) -> (Vec<u8>, u32, u32, u32) {
        let code = QrCode::new(payload.as_bytes()).expect("qr encodes");
        let modules = code.width();
        let colors = code.to_colors();
        let side = (modules + 2 * QUIET) * SCALE;
        let stride = side + pad;
        let mut buf = vec![0xFFu8; stride * side];
        for my in 0..modules {
            for mx in 0..modules {
                if colors[my * modules + mx] == Color::Dark {
                    for dy in 0..SCALE {
                        for dx in 0..SCALE {
                            let x = (mx + QUIET) * SCALE + dx;
                            let y = (my + QUIET) * SCALE + dy;
                            buf[y * stride + x] = 0x00;
                        }
                    }
                }
            }
        }
        // Poison the padding so a stride bug reads garbage, not white.
        for y in 0..side {
            for x in side..stride {
                buf[y * stride + x] = 0x55;
            }
        }
        (buf, side as u32, side as u32, stride as u32)
    }

    #[test]
    fn decodes_npub_payload_with_tight_stride() {
        let (buf, w, h, stride) = render(NPUB, 0);
        assert_eq!(decode_qr_luma(buf, w, h, stride), vec![NPUB.to_string()]);
    }

    #[test]
    fn decodes_when_stride_exceeds_width() {
        let (buf, w, h, stride) = render(NPUB, 13);
        assert!(stride > w);
        assert_eq!(decode_qr_luma(buf, w, h, stride), vec![NPUB.to_string()]);
    }

    #[test]
    fn blank_frame_decodes_nothing() {
        let buf = vec![0x80u8; 320 * 240];
        assert!(decode_qr_luma(buf, 320, 240, 320).is_empty());
    }

    #[test]
    fn inconsistent_geometry_returns_empty_without_panicking() {
        assert!(decode_qr_luma(vec![0; 10], 320, 240, 320).is_empty());
        assert!(decode_qr_luma(vec![0; 320 * 240], 320, 240, 100).is_empty());
        assert!(decode_qr_luma(Vec::new(), 0, 0, 0).is_empty());
    }
}
