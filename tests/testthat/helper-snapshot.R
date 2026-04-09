# Snapshot stabilisation helpers.
#
# Most candidate snapshots contain timestamps, file paths, or session-specific
# tokens that change every run. Pipe outputs through `stable()` (or pass it as
# `transform = stable_lines` to expect_snapshot) to remove that noise.

stable <- function(x) {
  if (length(x) == 0) return(x)
  x <- gsub("\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}(:\\d{2})?( ?UTC| ?Z)?", "TIMESTAMP", x)
  x <- gsub("\\b\\d{4}-\\d{2}-\\d{2}\\b", "DATE", x)
  x <- gsub("/private/tmp/[^ \"'<>]*", "TEMPFILE", x)
  x <- gsub("/tmp/[^ \"'<>]*", "TEMPFILE", x)
  x <- gsub("file[a-f0-9]{6,}", "TEMPFILE", x)
  x <- gsub("Rtmp[A-Za-z0-9]+", "RTMP", x)
  x
}

# Convenience for `transform = stable_lines` arg of expect_snapshot
stable_lines <- function(lines) stable(lines)
