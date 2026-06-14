# Jellyfin Player

A small Flutter-based Jellyfin client focused on reliable playback for large movies and shows.

## Current slice

- Connects to a Jellyfin server with username/password auth.
- Saves the session locally.
- Lists visible Jellyfin libraries.
- Browses library items and simple series/folder children.
- Opens playable movies, episodes, and videos through `media_kit`.
- Includes Android TV launcher metadata and local HTTP support for home servers.

## Run

```sh
flutter run
```

For Android TV, start an Android TV emulator or attach a device, then choose it from `flutter devices`.

## Notes

Playback currently uses Jellyfin's static stream URL with the API key in the query string. That is the first reliable baseline; the next step is adding playback session reporting, stream/transcode selection, subtitles, audio track switching, and resume position support.
