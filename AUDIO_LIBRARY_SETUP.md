# Audio Library Feature - Setup Guide

## What's New
A new "Audio" tab has been added to the mobile app's bottom navigation menu. This tab displays all locally recorded/saved audio files with full playback capabilities.

## Features
✅ View all local audio files  
✅ Play/pause audio with progress tracking  
✅ Display file metadata (duration, size, date)  
✅ Delete audio files  
✅ Pull-to-refresh  
✅ Empty state messaging  
✅ Error handling  

## Files Added

### Models
- `lib/models/audio_file_model.dart` - Audio file data model

### Services
- `lib/services/audio_file_service.dart` - Audio file management service

### Screens
- `lib/screens/audio_library_screen.dart` - Audio library UI

### Updated Files
- `lib/screens/home_screen.dart` - Added Audio menu item

## Installation

### 1. Ensure Dependencies
The app already has `audioplayers` in pubspec.yaml. If not, add:

```yaml
dependencies:
  audioplayers: ^6.1.0
  path_provider: ^2.1.5
```

Then run:
```bash
flutter pub get
```

### 2. Build & Run
```bash
flutter run
```

## Usage

### For End Users
1. Open the mobile app
2. Tap the "Audio" tab in the bottom navigation (music note icon)
3. View all recorded/saved audio files
4. Tap any file to play it
5. Tap the play button again to pause
6. Swipe left or tap the menu to delete files
7. Pull down to refresh the list

### For Developers
```dart
// Import the service
import 'services/audio_file_service.dart';

// Get all audio files
final audioService = AudioFileService();
final files = await audioService.getAllAudioFiles();

// Delete a file
await audioService.deleteAudioFile(file.path);

// Rename a file
await audioService.renameAudioFile(oldPath, newName);
```

## File Storage
Audio files are stored in:
```
/data/data/com.mysterymentor.app/app_flutter/
```

Supported formats:
- MP3
- WAV
- M4A
- AAC
- OGG
- WEBM
- FLAC
- WMA

## Navigation Structure
```
HomeScreen
├── Record (CallRecorderScreen)
├── Upload (CallUploadScreen)
├── Audio (AudioLibraryScreen) ← NEW
└── History (CallHistoryScreen)
```

## UI Components

### Audio List Item
- **Icon**: Play/pause button with gradient
- **Title**: Audio file name
- **Metadata**: Duration, size, creation date
- **Progress Bar**: Shows during playback
- **Menu**: Delete option

### Empty State
Shows when no audio files exist with:
- Music note icon
- "No Audio Files" message
- Refresh button

## Customization

### Change Icon
Edit `home_screen.dart`:
```dart
_MenuItem(
  icon: Icons.music_note_outlined,  // Change this
  activeIcon: Icons.music_note_rounded,  // And this
  label: 'Audio',
  ...
)
```

### Change Colors
Edit `audio_library_screen.dart` and use `AppColors` from `main.dart`:
```dart
gradient: LinearGradient(
  colors: [AppColors.primary, AppColors.primaryDark],
)
```

### Change Supported Formats
Edit `audio_file_service.dart`:
```dart
bool _isAudioFile(String filename) {
  final audioExtensions = ['mp3', 'wav', 'm4a', ...];  // Add/remove formats
  ...
}
```

## Troubleshooting

### Audio files not showing?
- Ensure files are in `/app_flutter/` directory
- Check file permissions
- Try pull-to-refresh
- Restart the app

### Playback not working?
- Verify audio format is supported
- Check device audio settings
- Ensure sufficient storage space
- Check device volume is not muted

### Delete not working?
- Check file permissions
- Ensure file is not currently playing
- Try restarting the app

### App crashes on Audio tab?
- Ensure `audioplayers` package is installed
- Run `flutter pub get`
- Clean build: `flutter clean && flutter pub get`
- Rebuild: `flutter run`

## Testing Checklist
- [ ] Audio tab appears in bottom navigation
- [ ] Audio files display correctly
- [ ] Playback works for all formats
- [ ] Progress bar updates smoothly
- [ ] Pause/resume works
- [ ] Delete with confirmation works
- [ ] Empty state displays correctly
- [ ] Pull-to-refresh works
- [ ] Error handling works
- [ ] UI is responsive
- [ ] Navigation works smoothly

## Future Enhancements
- Audio metadata extraction (duration, bitrate)
- Search/filter functionality
- Batch operations (delete multiple)
- Share audio files
- Audio editing (trim, cut)
- Favorites/bookmarks
- Playback speed control
- Equalizer settings
- Audio visualization
- Cloud sync

## Support
For issues or questions, check:
1. Flutter console output for errors
2. Device logs: `flutter logs`
3. Rebuild the app: `flutter clean && flutter run`
