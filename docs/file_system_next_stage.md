# File System Next Stage

## Product Target

LearnY's file system should not be "course files only".
It should become a unified learning asset system that covers:

- course files
- notification attachments
- homework teacher attachments
- homework submitted attachments
- homework answer attachments
- homework feedback/grade attachments
- excellent homework attachments
- future local previews for Office / video / zip / media

The goal is not to copy upstream learnX.
The goal is to exceed it in architecture, polish, and future extensibility.

## Architecture Direction

### 1. Unified asset model

All downloadable things should be represented as the same domain concept:

- stable identity
- source type
- course context
- title / type / size
- download url / preview url
- cache state
- preview capability

Current first step:

- `FileAttachment`
- `FileAttachmentEntry`
- `FileDetailRouteData`
- `FileDetailItem`

These let one detail screen support both normal course files and non-course attachments.

### 2. Separate concerns

- sync layer: fetch and persist metadata
- file domain: encode/decode attachment references, route payloads, view models
- download/cache layer: local paths, progress, deletion, integrity
- UI layer: lists, detail pages, preview panels, action bars

### 3. Page contract stays stable

We preserve the existing file detail page behavior and visuals as much as possible.
Refactors should change the data path first, then improve capability.

## Capability Gaps Still To Close

### Metadata / persistence

- persist excellent homework list in a usable local shape
- keep cache-registry records able to reconstruct file-detail routes after app restart
- decide whether non-course attachments get their own cache registry table
- add last-access / file-size / cache-limit metadata

### File detail

- use one route + one screen for all asset types
- support notification/homework attachments end-to-end
- later introduce richer preview strategies using preview urls where useful

### Cache system

- asset-level cache records are now the source of truth for both files and attachments
- cached asset records should carry enough route metadata for the file manager to reopen them
- cache-limit preference + LRU eviction service skeleton are in place
- expose cache limits in settings and tune product defaults
- support attachment cache visibility in file manager

### Preview system

- phase 1: PDF / image / text solid
- phase 2: Office preview strategy
- phase 3: mp4 / audio / zip / archive browsing

## Delivery Order

1. unify attachment route + detail entry model
2. persist attachment metadata from sync
3. wire notification/homework attachments into file detail
4. introduce asset cache registry
5. complete file settings and cache policy
6. build richer preview matrix

## Non-Negotiables

- do not break current refresh semantics
- do not casually rewrite the THU library
- preserve current UI/UX contract unless a targeted product upgrade is intentional
- prefer boundaries that future AIs can extend safely without creating new spaghetti
