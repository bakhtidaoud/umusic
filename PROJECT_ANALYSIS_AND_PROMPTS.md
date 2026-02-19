# 🚀 uMusic: Project Analysis & Completion Roadmap

As a Senior Full-Stack Developer, I have analyzed the current state of **uMusic**. The project has a solid foundation with high-performance video extraction and a modern GetX-based Home/Player system. However, to achieve a truly **Premium "YouTube Killer"** experience, we need to unify the architecture and polish the UI/UX.

---

## 🔍 Current Project Status
- **Architecture**: Pure GetX (Replaced Legacy Provider).
- **Core Features**: YouTube extraction (Audio/Video), Downloader with progress, Native Player (PodPlayer), Subscriptions tracking, Proxy support.
- **Visuals**: Dark-mode focused, Outfit typography, premium glassmorphism.
- **Status**: Phase 1 (Architecture Unification) COMPLETED.

---

## 🛠️ Implementation Roadmap

### Phase 1: Architecture Unification (The "Engine" Upgrade)
*   **Goal**: Migrate all remaining services (`DownloadService`, `ConfigService`, `SubscriptionService`) to GetX Controllers.
*   **Benefit**: Unified reactive state, faster navigation, and zero overhead between modules.

### Phase 2: Premium UI System (The "Look & Feel")
*   **Goal**: Create a `UDesign` utility class for unified coloring (HSL gradients), consistent spacing, and custom glassmorphism widgets.
*   **Features**: Skeleton loaders for all screens, localized animations, and high-fidelity transitions.

### Phase 3: Advanced Media Experience
*   **Goal**: Enable background audio playback and a "Mini-Player" that stays visible while browsing.
*   **Goal**: Implementation of a "Local Library" screen to manage and play downloaded files offline with a beautiful UI.

---

## 🤖 AI Agent Prompts for Completion

Use these prompts sequentially to instruct an AI agent to complete the project with extreme focus on **Premium Design** and **Performance**.

### Prompt 1: Unified GetX Architecture Migration
> "Rewrite `ConfigService`, `DownloadService`, and `SubscriptionService` in `lib/services` into GetX Controllers (`ConfigController`, `DownloadController`, `SubscriptionController`). Ensure all dependency injection is handled via `Get.put()` or `Bindings`. Remove all dependencies on the `provider` package from `pubspec.yaml` and the entire project. Ensure the app works faster by utilizing `obs` reactive variables for all states (download progress, settings, sub lists)."

### Prompt 2: The Premium Design System (`UDesign`)
> "Create a `lib/utils/design_system.dart` file. Define a `UDesign` class that includes:
> 1. A custom HSL ColorScheme (Deep Purples, Neon Accents, Glass Backgrounds).
> 2. Static methods for `GlassDecoration()` and `PremiumShadows()`.
> 3. Unified Padding and Border Radius constants (standardize on 24px and 32px for cards).
> Use this system to rewrite the `CustomDrawer` and `HomeScreen` to look like a high-end premium app (use more gradients, subtle blurs, and micro-interactions)."

### Prompt 4: The Intelligent Local Library
> "Create a `LocalLibraryScreen` that automatically scans the user's download folder. Display files with metadata (extract thumbnails from videos). Implement a beautiful 'Offline' player. Use `flutter_staggered_animations` for the file list. Add a search bar for local files. Use GetX for state management so new downloads appear instantly in the library."

### Prompt 5: Advanced Player & Background Audio
> "Enhance the `VideoPlayerScreen` and `PlayerController`. Integrate `just_audio` or background capabilities into `pod_player`. Add a 'Background Audio' toggle that continues music playback when the app is minimized. Create a 'Mini-Player' widget that appears at the bottom of the Home screen when a video is active, allowing the user to browse while listening (PIP feel)."

### Prompt 6: Search Suggestions & Optimized Discovery
> "Update `HomeController` to include YouTube search suggestions as the user types. Optimize the search query to show 'Shorts' separately or in a specific horizontal scroll list. Add 'Category Tags' (Music, Gaming, News) at the top of the Home feed to filter results dynamically without refreshing the whole page."

---

## 📈 Performance Checklist for Agent
- [ ] **Lazy Loading**: Ensure `Get.lazyPut` is used for screens not immediately visible.
- [ ] **Memory**: Call `dispose()` on all controllers and controllers' secondary services.
- [ ] **Image Optimization**: Always use `CachedNetworkImage` with custom `memCacheWidth/Height`.
- [ ] **Binary Size**: Ensure `NativeService` cleans up temporary yt-dlp assets.

**Final Goal**: A project where everything is GetX, every button has a micro-animation, and the code is 100% reactive.
