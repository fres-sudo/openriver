//! Import preflight only. No room parser is implemented yet.

use thiserror::Error;

pub const MAX_SOURCE_BYTES: usize = 32 * 1024 * 1024;
pub const PARSER_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ImportError {
    #[error("hand history is empty")]
    EmptySource,
    #[error("hand history exceeds the 32 MiB limit")]
    SourceTooLarge,
    #[error("hand history must be UTF-8")]
    InvalidEncoding,
    #[error("no supported hand-history parser is installed yet")]
    UnsupportedFormat,
}

/// Bound and validate input before format detection; never silently accept hands.
pub fn preflight(source: &[u8]) -> Result<&str, ImportError> {
    if source.len() > MAX_SOURCE_BYTES {
        return Err(ImportError::SourceTooLarge);
    }
    let text = std::str::from_utf8(source).map_err(|_| ImportError::InvalidEncoding)?;
    if text.trim().is_empty() {
        return Err(ImportError::EmptySource);
    }
    Ok(text)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_invalid_input_before_parsing() {
        assert_eq!(preflight(b" \n"), Err(ImportError::EmptySource));
        assert_eq!(preflight(&[0xff]), Err(ImportError::InvalidEncoding));
        assert_eq!(
            preflight(&vec![b'a'; MAX_SOURCE_BYTES + 1]),
            Err(ImportError::SourceTooLarge)
        );
        assert_eq!(preflight(b"synthetic history"), Ok("synthetic history"));
    }
}
