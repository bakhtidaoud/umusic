# uMusic Completion Plan: Prompts for AI

This document contains a series of structured prompts to complete the uMusic project with premium design, advanced features, and seamless functionality.

---

## Phase 1: Premium Design System & UI Overhaul
**Goal**: Elevate the UI to a "Premium" and "State-of-the-art" level.

### Prompt 1.1: Design System Enhancement
> "Enhance the existing `lib/utils/design_system.dart` to create a more premium feel. 
> 1. Use a more sophisticated color palette (e.g., Deep Indigo, Vibrant Violet, and Pure Cyan).
> 2. **Premium Light Mode**: Redesign the Light Mode to be modern and airy. Use 'Soft White' (#F8F9FA) for backgrounds, subtle 'Elevation' shadows instead of borders, and refined primary colors that don't look generic.
> 3. Implement advanced Glassmorphism with varied blur levels and subtle borders (frosted glass for light mode, deep glass for dark mode).
> 4. Add custom Shimmer effects for loading states.
> 5. Define typography styles using 'Outfit' or 'Inter' with proper weight and spacing.
> 6. Create a set of custom 'Micro-Interaction' utility classes for smooth animations."

### Prompt 1.2: Home Screen redesign
> "Redesign `lib/screens/home_screen.dart` and `lib/widgets/video_card.dart` (create if needed) to match the premium design system.
> 1. Use a staggered grid or a dynamic layout for videos.
> 2. Implement high-quality thumbnails with rounded corners and subtle shadows.
> 3. Add hover effects (for desktop/web) and tap animations.
> 4. Create a personalized 'Welcome' header that changes based on login status.
> 5. Ensure the Shorts section looks distinct with a vertical scroll or specialized cards."

---

## Phase 2: Advanced Geolocation & Personalization
**Goal**: Implement the requested logic for personalized content and geo-trending.

### Prompt 2.1: Geolocation Service
> "Create `lib/services/geo_service.dart` to fetch the user's country code using `https://ipinfo.io/json`.
> 1. Implement error handling and caching (so it doesn't fetch on every app start).
> 2. Return a country code (e.g., 'US', 'GB') to be used for YouTube trending results."

### Prompt 2.2: HomeController Logic Update
> "Update `lib/controllers/home_controller.dart` to implement the following logic:
> 1. Check if the user is logged in (using `CookieController`).
> 2. **If Logged In**: Fetch the user's subscriptions and recommended videos/shorts from YouTube.
> 3. **If NOT Logged In**: 
>    - Fetch the country code using `GeoService`.
>    - Fetch trending videos and shorts specifically for that country.
>    - Show a beautiful 'Login to see your personalized feed' message using the premium design system.
> 4. Ensure the loading state is smooth and uses the new shimmer effects."

---

## Phase 3: Comprehensive Downloads & Quality Selection
**Goal**: Allow users to download any quality and format.

### Prompt 3.1: Quality Selection Sheet
> "Create a premium BottomSheet (`lib/widgets/download_quality_sheet.dart`) that appears when a user clicks download.
> 1. It should fetch all available formats (audio and video) using `ExtractionService`.
> 2. Group formats by type (Video with Audio, Video Only, Audio Only).
> 3. Display resolution, bitrate, size, and codec for each option.
> 4. Allow the user to select their desired quality and start the download."

### Prompt 3.2: Download Controller Enhancements
> "Update `lib/controllers/download_controller.dart` to support specific format IDs.
> 1. Handle muxing if the user selects a 'Video Only' + 'Audio Only' combination (using `yt-dlp` or similar if available).
> 2. Improve the progress tracking and notification system to be more robust.
> 3. Add support for downloading metadata (tags, covers) for audio files."

---

## Phase 4: Performance & Polish
**Goal**: Ensure the app is fast and complete.

### Prompt 4.1: Performance Optimization
> "Optimize the application performance:
> 1. Implement more aggressive caching for thumbnails and search results.
> 2. Use `Isolate` for heavy data parsing or extraction.
> 3. Ensure all list views use builders for memory efficiency.
> 4. Audit the app for any frame drops during navigation."

### Prompt 4.2: Final Polish & "Missing Features"
> "Audit the entire project and implement these 'often forgotten' features:
> 1. Robust error handling for network outages (offline state).
> 2. A 'Clear Cache' and 'Data Usage' section in Settings.
> 3. Improved Player UI with better gesture controls (double tap to seek, swipe for volume/brightness).
> 4. **Theme Consistency**: Ensure all screens look perfect in both Premium Dark and Premium Light modes.
> 5. Proper deep linking support for YouTube URLs."

---

## How to use these prompts:
1.  Run them in sequence from Phase 1 to Phase 4.
2.  Review the output after each prompt to ensure it aligns with the 'Premium' aesthetic.
3.  If a build error occurs, provide the error message and ask the AI to fix it immediately.
