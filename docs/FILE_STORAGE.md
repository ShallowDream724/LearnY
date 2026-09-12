# File Storage

LearnY stores downloaded learning assets below the user's application documents
directory:

```text
LearnY Files/
  <readable course name> [<encoded course id>]/
    <readable file name> [<encoded asset key>].<extension>
```

The readable parts make the workspace useful in a normal file manager. The
encoded identifiers make course and asset identity part of the path, so courses
with the same name and assets with the same title cannot overwrite one another.
Identifiers use URI component encoding to remain stable and path safe.

## Compatibility

`FileStorageWorkspaceService.prepare()` migrates the former `learnx_files` and
`learny_files` roots into `LearnY Files`. It also materializes downloaded files
at their identity-based paths and rewrites both course-file and cached-asset
records only after the destination exists.

Migration copies files referenced from older readable-name directories. It does
not delete those source files or unrelated user-created files. Course-id legacy
directories are merged into their identified course directory, preserving the
existing conflict rule that keeps the non-empty, newer copy.

## Download Publication

Downloads are written to a unique staging file beside the final destination.
The payload is checked for HTTP status, empty content, and session-expiry HTML
before publication. A validated staging file is published with a same-directory
rename. When replacing an existing destination, a temporary backup is retained
until publication succeeds, allowing restoration if the rename fails.

Failed or rejected downloads remove their staging file. An existing valid
download and its persisted cache record remain usable; Dio's default
`deleteOnError` behavior may already remove a staging file after transport
failure, and cleanup is therefore idempotent.

Download progress exposes only a previously published local path, never the
future destination. Inline readers are mounted only after `downloaded`, after
validation, publication and cache persistence; transfer progress reaching 100%
alone is insufficient. During a replacement download the reader is unmounted,
so completion opens the new file even when its path is unchanged. This applies
to PDF, ZIP, images and text through the common file detail screen.

Preview preparation awaits text/ZIP work inside its error boundary so asynchronous
read/parse failures return the normal preview fallback.

## PDF and ZIP Preview

PDFs use the local `pdfrx` 2.2.24 Flutter viewer with `pdfrx_engine` 0.3.9/PDFium,
after the download has been published. Reader controls, page navigation and
text selection live in `PdfPreviewSurface`. This engine version maps every
Windows open failure to `PdfPasswordException`, so that error alone does not
prove encryption; attempting to open an unpublished path was one such failure.

ZIP is an active preview capability: registry → preparation service → archive
inspection → archive browser → selected-entry extraction → shared file preview.
The archive service owns filename decoding, extraction paths and caching; the
browser owns navigation and actions. It currently reads the whole archive and
uses `archive`'s ZIP decoder; it is not a streaming archive implementation.

The `.archive` directory under `LearnY Files` remains reserved for extracted
archive previews.
