//! Existing-file lyrics with caller-owned file access and cancellation.

use super::text_from_bytes;
use std::io::{Read, Seek};

const MAX_SIDECAR_BYTES: usize = 8 * 1024 * 1024;

pub fn extract<R: Read + Seek>(
    path: &str,
    open: &impl Fn(&str) -> Result<R, String>,
    check: &dyn Fn() -> Result<(), String>,
) -> Result<String, String> {
    check()?;
    // Match filepath.Ext, including dotfiles and trailing dots on Unix.
    let suffix = path
        .rfind('.')
        .filter(|index| !path[*index..].contains('/'));
    let format = suffix.map_or_else(String::new, |index| path[index + 1..].to_ascii_lowercase());
    if matches!(
        format.as_str(),
        "flac" | "m4a" | "mp4" | "aac" | "mp3" | "opus" | "ogg" | "wav" | "aiff" | "aif" | "aifc"
    ) && let Ok(metadata) =
        open(path).and_then(|mut file| crate::tags::read_audio_tags(&mut file, &format, check))
    {
        check()?;
        if !metadata.lyrics.trim().is_empty() {
            return Ok(metadata.lyrics);
        }
        if !matches!(format.as_str(), "flac" | "m4a" | "mp4" | "aac")
            && looks_like_lyrics(&metadata.comment)
        {
            return Ok(metadata.comment);
        }
    }
    check()?;
    sidecar(path, open, check)
}

pub fn sidecar<R: Read>(
    path: &str,
    open: &impl Fn(&str) -> Result<R, String>,
    check: &dyn Fn() -> Result<(), String>,
) -> Result<String, String> {
    check()?;
    let suffix = path
        .rfind('.')
        .filter(|index| !path[*index..].contains('/'));
    let base = &path[..suffix.unwrap_or(path.len())];
    if base.trim().is_empty() {
        return Err("no lyrics found in file".into());
    }
    let mut file = open(&format!("{base}.lrc"))?;
    let mut bytes = Vec::new();
    let mut buffer = [0; 16 * 1024];
    loop {
        check()?;
        let count = file.read(&mut buffer).map_err(|error| error.to_string())?;
        if count == 0 {
            break;
        }
        if bytes.len() + count > MAX_SIDECAR_BYTES {
            return Err("lyrics sidecar exceeds size limit".into());
        }
        bytes.extend_from_slice(&buffer[..count]);
    }
    check()?;
    let text = text_from_bytes(&bytes).trim().to_owned();
    if text.is_empty() {
        Err("no lyrics found in file".into())
    } else {
        Ok(text)
    }
}

fn looks_like_lyrics(text: &str) -> bool {
    let text = text.trim();
    let lower = text.to_ascii_lowercase();
    lower.contains("[ar:")
        || lower.contains("[ti:")
        || (text.contains('\n') && text.contains('[') && text.contains(']'))
}

/// Offline Vorbis comment lyrics exporter to a .lrc file.
pub fn export_vorbis_to_lrc(
    audio_path: &str,
    output_path: Option<&str>,
    check: &dyn Fn() -> Result<(), String>,
) -> Result<(String, String), String> {
    check()?;
    let mut file = std::fs::File::open(audio_path).map_err(|e| format!("open audio file: {e}"))?;
    let suffix = audio_path.rfind('.').filter(|idx| !audio_path[*idx..].contains('/'));
    let format = suffix.map_or_else(String::new, |idx| audio_path[idx + 1..].to_ascii_lowercase());
    let metadata = crate::tags::read_audio_tags(&mut file, &format, check)
        .map_err(|e| format!("read audio tags: {e}"))?;
    check()?;
    let lyrics_text = if !metadata.lyrics.trim().is_empty() {
        metadata.lyrics
    } else if looks_like_lyrics(&metadata.comment) {
        metadata.comment
    } else {
        return Err("no Vorbis lyrics found in audio tags".into());
    };

    let target_path = match output_path {
        Some(p) if !p.trim().is_empty() => p.to_string(),
        _ => {
            let base = &audio_path[..suffix.unwrap_or(audio_path.len())];
            format!("{base}.lrc")
        }
    };

    std::fs::write(&target_path, lyrics_text.as_bytes())
        .map_err(|e| format!("write lrc file: {e}"))?;
    Ok((target_path, lyrics_text))
}
