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

Downloads and inline HTML images share structural session-page detection with
the API client. Learn's HTTP 200 expiry pages and HTTP 401/403 can trigger one
recovery; ordinary HTML, redirects mentioned in course prose, and transport
failures cannot trigger credential submission. Even an HTML attachment is
rejected if it is an actual login page. CSRF is attached only to the exact Learn
HTTPS host and recomputed for each attempt after recovery. The inspector decodes
an 8192-byte prefix as UTF-8 so Chinese error markers remain recognizable.
MIME is not treated as proof of file format; see the bounded production samples
in [SCHOOL_INTERFACES.md](SCHOOL_INTERFACES.md).

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

## Saving Images to the Gallery

On mobile, long-press an image and select “保存到相册”. This action is shared by
notification/assignment/feedback HTML, their full-screen image viewer, and file
previews (including extracted archive images). `SaveableImage` owns the menu,
in-flight guard and feedback; `ImageGalleryService` exports through `gal` 2.3.3.
HTML images reuse their loaded bytes, with a temporary file named from the actual
image format; attachments export the published local file. Originals are copied
without re-downloading or recompressing. Temporary export files are removed after
the save operation. Android 9 and earlier request write permission when saving;
modern Android writes through MediaStore. iOS declares photo-library usage keys.
