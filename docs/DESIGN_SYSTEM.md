# Klymb — Design System

> **Version:** 0.1 (MVP)
> **Last updated:** 2026-11-21
> **Status:** Draft — awaiting founder approval
> **Depends on:** [PRD.md](./PRD.md)

---

## 1. Design Philosophy

Klymb is a **game**, not a health app. Every pixel should feel like a **premium competitive gaming platform** — think Valorant's UI meets Apple Fitness+ 's polish, wrapped in a dark, moody aesthetic with one electric accent color that screams energy.

### Design Pillars

| Pillar | Meaning |
|---|---|
| **Dark & premium** | Deep blacks and grays. Never clinical white. The UI should feel like a nightclub, not a hospital. |
| **Competitive energy** | Every screen should make you want to beat someone. Ranks, arrows, flames, momentum. |
| **Rewarding motion** | Numbers count up. Badges glow. Streaks burn. Every achievement hits with dopamine. |
| **Effortless clarity** | Dark doesn't mean cluttered. Generous spacing, clear hierarchy, instant readability. |
| **Accessible by default** | Dynamic Type, VoiceOver, Reduce Motion, contrast — all baked in from day one. |

---

## 2. Color Tokens

### 2.1 Core Palette

| Token | Light Mode | Dark Mode (Default) | Usage |
|---|---|---|---|
| `background.primary` | `#FFFFFF` | `#0A0A0F` | Main screen background |
| `background.secondary` | `#F5F5F7` | `#141420` | Cards, elevated surfaces |
| `background.tertiary` | `#E8E8ED` | `#1C1C2E` | Nested containers, input fields |
| `surface.elevated` | `#FFFFFF` | `#1E1E32` | Modals, sheets, popovers |
| `text.primary` | `#1A1A1A` | `#F0F0F5` | Headings, body text |
| `text.secondary` | `#6B6B80` | `#8E8EA0` | Captions, labels, metadata |
| `text.tertiary` | `#9B9BAD` | `#5C5C6E` | Placeholders, disabled text |
| `text.inverse` | `#F0F0F5` | `#0A0A0F` | Text on accent backgrounds |
| `border.default` | `#E0E0E8` | `#2A2A3D` | Dividers, card borders |
| `border.subtle` | `#F0F0F5` | `#1E1E32` | Subtle separators |

### 2.2 Accent & Semantic Colors

| Token | Value | Usage |
|---|---|---|
| **`accent.primary`** | **`#00E5FF`** (Electric Cyan) | Primary actions, KP numbers, active states, the "Klymb" color |
| `accent.primaryMuted` | `#00E5FF` at 20% opacity | Accent backgrounds, selected states |
| `accent.secondary` | `#7B61FF` (Vivid Purple) | Secondary highlights, team badges, challenges |
| `semantic.success` | `#00D68F` | Verified badges, completed states, positive rank change |
| `semantic.warning` | `#FFB800` | Streak flame, pending states, caution |
| `semantic.error` | `#FF3D71` | Errors, revoked KP, negative rank change |
| `semantic.info` | `#00B4D8` | Informational banners, tips |

### 2.3 Rank Colors (for leaderboard tiers — post-MVP, but tokens defined now)

| Rank | Color | Token |
|---|---|---|
| Top 1 | Gold `#FFD700` | `rank.gold` |
| Top 2 | Silver `#C0C0C0` | `rank.silver` |
| Top 3 | Bronze `#CD7F32` | `rank.bronze` |
| Top 10 | Electric Cyan `#00E5FF` | `rank.elite` |
| Others | Default text | `text.secondary` |

### 2.4 Gradient Tokens

| Token | Gradient | Usage |
|---|---|---|
| `gradient.accent` | `#00E5FF` → `#7B61FF` (45°) | CTA buttons, KP counter glow, achievement unlock |
| `gradient.fire` | `#FF6B00` → `#FFB800` (vertical) | Streak flame, hot streaks |
| `gradient.card` | `#1E1E32` → `#141420` (vertical) | Card backgrounds (subtle depth) |
| `gradient.rank` | `#FFD700` → `#FF6B00` (45°) | Rank-up celebration |

### 2.5 Dark Mode Default

Klymb launches in **dark mode by default**. Light mode is supported for accessibility but dark is the brand identity. The app respects the system setting but defaults to dark on first launch if the system is set to "automatic."

---

## 3. Typography

### 3.1 Typeface

| Weight | iOS Font | Usage |
|---|---|---|
| **Bold** | SF Pro Display Bold | Large titles, KP numbers, rank numbers |
| **Semibold** | SF Pro Text Semibold | Section headers, button labels, emphasis |
| **Medium** | SF Pro Text Medium | Body text, card titles |
| **Regular** | SF Pro Text Regular | Body, descriptions, metadata |
| **Monospaced** | SF Mono Medium | KP counters (for alignment during count-up animation) |

SF Pro is the system font — no custom fonts needed, guaranteed availability, excellent Dynamic Type support.

### 3.2 Type Scale

| Token | Size (default) | Weight | Line Height | Usage |
|---|---|---|---|---|
| `title.hero` | 48pt | Bold | 1.1 | KP total on Home screen |
| `title.large` | 34pt | Bold | 1.15 | Screen titles |
| `title.medium` | 28pt | Bold | 1.2 | Section headers |
| `title.small` | 22pt | Semibold | 1.25 | Card titles, modal headers |
| `headline` | 17pt | Semibold | 1.3 | List row titles, emphasis |
| `body` | 17pt | Regular | 1.4 | Primary body text |
| `body.small` | 15pt | Regular | 1.4 | Secondary body text |
| `caption` | 13pt | Medium | 1.3 | Metadata, timestamps, labels |
| `caption.small` | 11pt | Regular | 1.2 | Footnotes, fine print |
| `kp.counter` | 48pt | Bold Mono | 1.0 | Animated KP count-up |
| `kp.inline` | 17pt | Semibold Mono | 1.0 | KP values in lists/cards |
| `rank.number` | 22pt | Bold Mono | 1.0 | Rank numbers in leaderboard |

### 3.3 Dynamic Type Support

All text must use the iOS text style system (`Font.TextStyle`) for automatic Dynamic Type scaling:

| Token | Maps to `TextStyle` |
|---|---|
| `title.hero` | `.largeTitle` (custom scaled) |
| `title.large` | `.largeTitle` |
| `title.medium` | `.title` |
| `title.small` | `.title2` |
| `headline` | `.headline` |
| `body` | `.body` |
| `body.small` | `.subheadline` |
| `caption` | `.caption` |
| `caption.small` | `.caption2` |

**Rules:**
- Never use fixed point sizes — always use `@ScaledMetric` or `Font.TextStyle`
- Test all screens at accessibility sizes (AX1 through AX5)
- Layouts must reflow gracefully (no truncation, no overlap)
- If text overflows, use `lineLimit(nil)` — never clip important content

---

## 4. Spacing & Layout

### 4.1 Spacing Scale (4pt base)

| Token | Value | Usage |
|---|---|---|
| `space.xxs` | 2pt | Icon-to-text micro gap |
| `space.xs` | 4pt | Tight inline spacing |
| `space.sm` | 8pt | Between related elements |
| `space.md` | 12pt | Standard component padding |
| `space.lg` | 16pt | Between sections, card padding |
| `space.xl` | 24pt | Between major sections |
| `space.xxl` | 32pt | Screen-level vertical padding |
| `space.xxxl` | 48pt | Hero spacing, breathing room |

### 4.2 Corner Radii

| Token | Value | Usage |
|---|---|---|
| `radius.sm` | 8pt | Small chips, tags, badges |
| `radius.md` | 12pt | Input fields, small cards |
| `radius.lg` | 16pt | Standard cards, buttons |
| `radius.xl` | 24pt | Large cards, modals |
| `radius.full` | 9999pt | Circular elements (avatars, rank badges) |

### 4.3 Elevation (Shadow)

Dark mode uses **border glow** instead of traditional shadows:

| Token | Implementation | Usage |
|---|---|---|
| `elevation.none` | No effect | Flat elements |
| `elevation.low` | 1pt border `border.default` | Cards at rest |
| `elevation.medium` | 1pt border `accent.primaryMuted` | Hovered/focused cards |
| `elevation.high` | 2pt border `accent.primary` + subtle glow (8pt blur, 10% opacity) | Active/selected elements, modals |

---

## 5. Iconography

### 5.1 Icon System

**Use SF Symbols exclusively** — consistent with iOS, supports Dynamic Type, weight matching, and accessibility.

| Context | Symbol Weight | Rendering |
|---|---|---|
| Tab bar | `.medium` | Monochrome, `text.secondary` (inactive), `accent.primary` (active) |
| Navigation bar | `.medium` | Monochrome, `text.primary` |
| Inline (body text) | `.regular` | Monochrome, inherits text color |
| Feature icons (cards) | `.semibold` | Hierarchical or Palette rendering |
| Achievement badges | `.bold` | Multicolor with accent palette |

### 5.2 Key Icons

| Element | SF Symbol | Notes |
|---|---|---|
| Home tab | `house.fill` | |
| Log tab | `plus.circle.fill` | |
| Compete tab | `trophy.fill` | |
| Challenges tab | `flag.fill` | |
| Profile tab | `person.fill` | |
| Steps | `figure.walk` | |
| Running | `figure.run` | |
| Workout | `dumbbell.fill` | |
| Hydration | `drop.fill` | |
| Sleep | `moon.fill` | |
| Mindfulness | `brain.head.profile` | |
| Walking | `figure.walk.motion` | |
| Streak flame | `flame.fill` | Tinted with `gradient.fire` |
| Rank up arrow | `arrow.up.circle.fill` | Tinted `semantic.success` |
| Rank down arrow | `arrow.down.circle.fill` | Tinted `semantic.error` |
| Verified badge | `checkmark.seal.fill` | Tinted `semantic.success` |
| Pending/flagged | `clock.fill` | Tinted `text.secondary` |
| KP symbol | `k.circle.fill` | Custom or `bitcoinsign.circle.fill` as placeholder |
| Team | `person.3.fill` | |
| Friends | `person.2.fill` | |

---

## 6. Motion & Animation

### 6.1 Motion Principles

| Principle | Detail |
|---|---|
| **Purposeful** | Every animation communicates meaning — earning, climbing, losing, achieving. No decoration-only motion. |
| **Quick** | Default duration: 0.3s. Never block user interaction. |
| **Responsive** | Spring animations for interactive elements. Ease-out for transitions. |
| **Celebratory** | Go bigger for milestone moments (rank-up, achievement, streak milestone). |
| **Respectful** | All motion respects `UIAccessibility.isReduceMotionEnabled`. |

### 6.2 Core Animations

#### KP Count-Up

The signature animation. When KP changes, the number "rolls" up from old value to new value.

```
Duration: 0.8s (or 1.2s for large differences > 100 KP)
Easing: ease-out (fast start, slow finish — feels like momentum)
Font: kp.counter (monospaced so digits don't shift)
Color: accent.primary with subtle pulse glow at the end
Sound: Optional subtle "ding" on completion (respects silent mode)
Reduce Motion fallback: Instant number change with brief highlight
```

#### Rank-Up Celebration

When user's rank improves (detected on leaderboard refresh):

```
Step 1: Rank number scales up 1.3× (0.2s spring)
Step 2: accent.primary ring expands outward (0.4s)
Step 3: Confetti particle burst — cyan + purple (0.6s, 20 particles)
Step 4: Settle back to normal with glow (0.3s)
Total: ~1.0s
Reduce Motion fallback: Rank badge briefly highlights with accent border
```

#### Streak Flame

Animated flame icon next to streak count:

```
Idle: Gentle flicker (looping, 2s cycle, subtle scale 1.0–1.05)
Milestone hit: Flame grows 2×, particles fly up (0.8s), settles back
Streak broken: Flame fades out with smoke particles (0.6s)
Reduce Motion fallback: Static flame icon (no flicker)
```

#### Achievement Unlock

```
Step 1: Lock icon shatters (0.3s)
Step 2: Achievement icon fades in with scale-up from 0.5× to 1.0× (0.4s spring)
Step 3: Accent glow ring (0.3s)
Step 4: "+100 KP" floats up and fades (0.5s)
Reduce Motion fallback: Cross-dissolve from locked to unlocked state
```

#### Tab Transitions

```
Between tabs: Horizontal slide (0.25s, interruptible)
Within navigation stack: Push/pop (0.3s, standard iOS)
Sheets: Spring bottom-up (0.4s spring)
Reduce Motion fallback: Cross-dissolve (0.2s)
```

#### Pull to Refresh

```
Over-scroll: Custom Klymb spinner (rotating accent ring)
Syncing: Ring pulses
Complete: Checkmark morphs from ring (0.3s)
```

### 6.3 Timing Tokens

| Token | Duration | Curve | Usage |
|---|---|---|---|
| `anim.instant` | 0.1s | linear | Opacity toggles, micro-feedback |
| `anim.fast` | 0.2s | ease-out | Button presses, state changes |
| `anim.default` | 0.3s | ease-in-out | Standard transitions |
| `anim.medium` | 0.5s | ease-out | Cards expanding, reveals |
| `anim.slow` | 0.8s | ease-out | KP count-up, celebrations |
| `anim.spring` | — | spring(response: 0.4, dampingFraction: 0.75) | Interactive, bouncy elements |

---

## 7. Haptic Patterns

| Event | Haptic Type | iOS API |
|---|---|---|
| KP earned | `.success` | `UINotificationFeedbackGenerator` |
| Rank up | `.success` + custom pattern | `UINotificationFeedbackGenerator` → `CHHapticEngine` burst |
| Rank down | `.warning` | `UINotificationFeedbackGenerator` |
| Achievement unlocked | Heavy impact + success | `UIImpactFeedbackGenerator(.heavy)` → `.success` |
| Streak milestone | Triple tap pattern | `CHHapticEngine` custom pattern (tap-tap-tap) |
| Streak broken | `.error` | `UINotificationFeedbackGenerator` |
| Button tap | `.light` | `UIImpactFeedbackGenerator(.light)` |
| Tab switch | `.selection` | `UISelectionFeedbackGenerator` |
| Pull to refresh complete | `.medium` | `UIImpactFeedbackGenerator(.medium)` |
| Challenge joined | `.medium` + `.success` | Sequence |
| Manual log confirmed | `.success` | `UINotificationFeedbackGenerator` |
| Error | `.error` | `UINotificationFeedbackGenerator` |

**Rules:**
- Never fire haptics when `UIAccessibility.isReduceMotionEnabled` is true (some users find haptics disorienting)
- Respect silent mode / Do Not Disturb for any audio
- Haptic intensity should match the importance of the event

---

## 8. Tone of Voice & Copy

### 8.1 Voice Characteristics

| Attribute | Klymb Voice |
|---|---|
| **Personality** | Competitive friend — pushes you but celebrates with you |
| **Tone** | Energetic, direct, slightly cocky — never corporate or clinical |
| **Language** | Short sentences. Active voice. Gaming vocabulary (rank, climb, grind, crush). |
| **Emotion** | Hype for wins. Empathy for losses. Never judgmental about health. |
| **Formality** | Casual but not sloppy. No slang that ages. No emojis in body text (OK in notifications). |

### 8.2 Sample Copy

| Context | ❌ Don't | ✅ Do |
|---|---|---|
| Earning KP | "You have been awarded 80 Klymb Points for your walking activity." | "**+80 KP** — nice walk." |
| Streak | "You have maintained a 7-day activity streak. Congratulations." | "**7-day streak 🔥** You're on fire. Don't stop now." |
| Overtaken | "Another user has surpassed your position on the leaderboard." | "**@ravi just passed you.** Time to take it back." |
| Rank up | "Your rank has improved to #12." | "**#12 in Bangalore.** You climbed 3 spots today." |
| Challenge | "A new daily challenge is available for you to participate in." | "**New challenge: 10K steps today.** 50 KP if you crush it." |
| Empty leaderboard | "There are no entries to display." | "**No one's here yet.** Be the first to claim #1." |
| Error | "An error occurred. Please try again." | "**Something broke.** We're on it. Try again?" |
| Streak broken | "Your streak has ended." | "**Streak lost.** It happens. Start a new one today." |
| Manual entry | "Please enter the quantity manually." | "**Quick log** — tap to record." |
| Offline | "No internet connection detected." | "**You're offline.** We'll sync when you're back." |
| Achievement | "Achievement unlocked: First Steps" | "**First Steps unlocked! 🏆** +50 KP. The climb begins." |
| Onboarding welcome | "Welcome to Klymb health tracking application." | "**Your city is watching.** Let's see what you've got." |
| KP cap hit | "Daily limit reached for this habit." | "**Maxed out for today.** Come back stronger tomorrow." |

### 8.3 Number Formatting

| Type | Format | Example |
|---|---|---|
| KP (small) | No separator | 847 |
| KP (large) | Comma separator | 12,450 |
| KP change | Signed, bold | **+80**, **−150** |
| Rank | Hash prefix, bold | **#12** |
| Rank change | Arrow + number, colored | ↑3 (green), ↓1 (red), — (gray) |
| Streak | Number + flame | 15 🔥 |
| Distance | 1 decimal + unit | 4.2 km |
| Steps | Comma separator | 8,432 |
| Duration | h:mm or Xm | 1:30 or 45m |
| Percentage | Rounded integer | 78% |
| Water | No decimal + unit | 750 ml |

---

## 9. Component Inventory

### 9.1 PrimaryButton

```
Style: Filled, gradient.accent background, text.inverse text
Height: 50pt
Corner radius: radius.lg (16pt)
Font: headline (Semibold 17pt)
States:
  - Default: gradient.accent fill
  - Pressed: 0.95× scale + 90% opacity (anim.instant)
  - Disabled: 40% opacity, no interaction
  - Loading: Text replaced with spinner (accent.primary)
Haptic: .light on tap
Full-width in forms, intrinsic-width in toolbars
```

### 9.2 SecondaryButton

```
Style: Outlined, border accent.primary, text accent.primary
Height: 50pt
Corner radius: radius.lg (16pt)
Font: headline
States:
  - Default: transparent fill, accent.primary border
  - Pressed: accent.primaryMuted fill
  - Disabled: 40% opacity
```

### 9.3 Card

```
Background: background.secondary
Border: 1pt border.default
Corner radius: radius.xl (24pt)
Padding: space.lg (16pt)
Shadow: elevation.low
Pressed state: elevation.medium (anim.fast)
Content: Flexible — title, subtitle, icon, action area
```

### 9.4 RankBadge

```
Shape: Circle (radius.full)
Size: 36pt × 36pt (compact), 48pt × 48pt (standard)
Background:
  - Top 1: gradient radial gold
  - Top 2: silver solid
  - Top 3: bronze solid
  - Top 10: accent.primary at 15% opacity
  - Others: background.tertiary
Text: rank.number font, centered
Border: 2pt matching rank color (top 3) or border.default
Animation on rank change: scale spring (anim.spring)
```

### 9.5 ProgressRing

```
Size: 120pt × 120pt (home), 48pt × 48pt (compact)
Track: background.tertiary, 6pt stroke
Fill: accent.primary (or gradient.accent for > 80%)
Cap: round
Center content: Percentage or icon
Animation: Stroke draws from 0 to current (anim.slow, ease-out)
Over 100%: Second lap in accent.secondary
Reduce Motion: Instant fill, no animation
```

### 9.6 KPCounter

```
Font: kp.counter (48pt Bold Mono) — home; kp.inline (17pt) — elsewhere
Color: accent.primary
Animation: Rolling count-up (see §6.2)
Prefix: "+" for gains (semantic.success), "−" for losses (semantic.error)
Glow: subtle accent.primary shadow on home counter
Accessibility label: "1,247 Klymb Points earned today"
```

### 9.7 LeaderboardRow

```
Layout: [RankBadge] [Avatar] [Username + City] [KP] [RankChange]
Height: 64pt
Background: background.secondary (or accent.primaryMuted for "my row")
Border-bottom: 1pt border.subtle
"My row" variant:
  - Pinned at bottom of list
  - Highlighted with accent.primaryMuted background
  - Bold text
  - Subtle left accent bar (2pt, accent.primary)
Tap: Opens public profile sheet
```

### 9.8 ChallengeCard

```
Layout: Vertical — [Icon + Title] [Progress bar] [Reward] [Time remaining]
Background: Card style with gradient.card
Corner radius: radius.xl
Progress bar: accent.primary fill on background.tertiary track, rounded caps
Reward badge: accent.secondary pill with KP amount
Status indicator:
  - Active: accent.primary dot
  - Upcoming: text.secondary dot
  - Completed: semantic.success checkmark
Tap: Opens challenge detail
```

### 9.9 StatTile

```
Layout: Vertical — [Icon] [Value] [Label]
Size: Flexible grid (2-column or 3-column)
Background: background.secondary
Corner radius: radius.lg
Value: title.small font, accent.primary color
Label: caption font, text.secondary
```

### 9.10 Toast

```
Position: Bottom of screen, above tab bar, 16pt margin
Background: surface.elevated with elevation.medium
Corner radius: radius.lg
Layout: [Icon] [Message] [Dismiss ×]
Duration: 4 seconds auto-dismiss (or tap to dismiss)
Animation: Slide up + fade in (0.3s), slide down + fade out (0.3s)
Types:
  - Success: semantic.success icon (checkmark.circle.fill)
  - Error: semantic.error icon (xmark.circle.fill)
  - Info: semantic.info icon (info.circle.fill)
  - KP earned: accent.primary icon (k.circle.fill) + "+80 KP" text
Accessibility: Announced via VoiceOver as notification
```

### 9.11 EmptyState

```
Layout: Centered — [Illustration/Icon] [Title] [Description] [CTA Button]
Icon: Large SF Symbol (60pt), text.tertiary
Title: title.small, text.primary
Description: body.small, text.secondary, max 2 lines
CTA: PrimaryButton or SecondaryButton
Examples:
  - No friends: person.2.slash, "No friends yet", "Find people to compete with", [Find Friends]
  - No challenges: flag.slash, "No active challenges", "New challenges drop daily", [Browse Challenges]
  - Empty leaderboard: trophy.fill, "No one's here yet", "Be the first to earn KP today", [Start Tracking]
```

### 9.12 ErrorState

```
Layout: Same as EmptyState
Icon: exclamationmark.triangle.fill (48pt), semantic.error
Title: "Something went wrong"
Description: User-friendly error message from ErrorMapper
CTA: "Try Again" (PrimaryButton) + "Go Back" (text button)
```

### 9.13 SkeletonLoader

```
Shape: Matches content layout (rounded rects for text, circles for avatars)
Color: background.tertiary
Animation: Shimmer — gradient sweep left-to-right (1.5s loop)
  - Gradient: background.tertiary → background.secondary → background.tertiary
  - Width: 40% of container
Reduce Motion fallback: Static gray placeholder (no shimmer)
Duration: Show skeleton immediately on load; cross-fade to content (anim.fast)
```

### 9.14 Avatar (Preset)

```
Shape: Circle (radius.full)
Sizes: 32pt (compact/list), 48pt (standard), 80pt (profile header), 120pt (edit)
Border: 2pt background.tertiary
Presets: 24 illustrated avatar options covering diverse representations
  - 8 human faces (diverse skin tones, genders)
  - 8 animal/mascot options (lion, eagle, wolf, dragon, fox, panda, tiger, phoenix)
  - 8 abstract/geometric (flame, lightning, diamond, star, crown, rocket, mountain, wave)
Fallback: First letter of username on accent.primary circle
```

---

## 10. Accessibility

### 10.1 Dynamic Type

| Rule | Implementation |
|---|---|
| All text uses `Font.TextStyle` | No hardcoded point sizes |
| Layouts reflow at large sizes | Horizontal stacks become vertical when needed |
| `@ScaledMetric` for spacing | Spacing scales proportionally |
| Minimum tap target | 44pt × 44pt at all sizes |
| Tested at AX5 | Every screen must be usable at the largest accessibility size |

### 10.2 VoiceOver

| Rule | Implementation |
|---|---|
| Every interactive element has a label | `.accessibilityLabel("Rank 12 in Bangalore")` |
| Grouped related content | `.accessibilityElement(children: .combine)` for card components |
| Reading order matches visual hierarchy | Use `.accessibilitySortPriority()` where needed |
| Custom actions for complex components | Leaderboard row: "View profile", "Add friend" |
| State announcements | KP changes: `.accessibilityAnnouncement("Plus 80 Klymb Points")` |
| Decorative elements hidden | `.accessibilityHidden(true)` for glows, particles, decorative icons |
| Images have descriptions | All avatars, badges, rank icons have descriptive labels |

### 10.3 Contrast

| Requirement | Standard |
|---|---|
| Text on background | ≥ 4.5:1 (WCAG AA for normal text) |
| Large text on background | ≥ 3:1 (WCAG AA for 18pt+ bold) |
| Interactive element borders | ≥ 3:1 against adjacent colors |
| `accent.primary` (#00E5FF) on `background.primary` (#0A0A0F) | **13.5:1** ✅ |
| `text.primary` (#F0F0F5) on `background.primary` (#0A0A0F) | **17.4:1** ✅ |
| `text.secondary` (#8E8EA0) on `background.primary` (#0A0A0F) | **5.8:1** ✅ |
| `text.secondary` (#8E8EA0) on `background.secondary` (#141420) | **4.6:1** ✅ |

### 10.4 Reduce Motion

Every animation has a `Reduce Motion` fallback:

| Animation | Standard | Reduce Motion Fallback |
|---|---|---|
| KP count-up | Rolling number animation | Instant number change with brief accent highlight |
| Rank-up celebration | Scale + confetti + glow | Accent border highlight (0.2s) |
| Streak flame | Looping flicker | Static flame icon |
| Achievement unlock | Shatter + scale + glow | Cross-dissolve from locked to unlocked |
| Tab transitions | Horizontal slide | Cross-dissolve |
| Skeleton shimmer | Gradient sweep | Static gray placeholder |
| Pull-to-refresh | Custom spinner rotation | Standard iOS activity indicator |
| Progress ring fill | Animated stroke draw | Instant fill |

**Implementation:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

withAnimation(reduceMotion ? .none : .spring(response: 0.4)) {
    // animation
}
```

### 10.5 Color Blindness

- Never rely on color alone to convey information
- Rank changes use **arrow icons + color** (not just green/red)
- Verification uses **icon + label** (not just green badge)
- Chart data uses **pattern fills** in addition to colors (post-MVP)

---

## 11. Screen Layout Templates

### 11.1 Standard Screen

```
┌────────────────────────────────┐
│  Navigation Bar (title, actions)│ 44pt
├────────────────────────────────┤
│                                │
│  Content (scrollable)          │
│                                │
│  space.xl between sections     │
│  space.lg padding horizontal   │
│                                │
├────────────────────────────────┤
│  Tab Bar                       │ 49pt + safe area
└────────────────────────────────┘
```

### 11.2 Home Screen Layout

```
┌────────────────────────────────┐
│  "Klymb" title    [avatar] [🔔]│
├────────────────────────────────┤
│                                │
│  🔥 15-day streak              │
│                                │
│    ╭────────────────╮          │
│    │   1,247 KP     │          │
│    │   ▲ +89 today  │          │
│    ╰────────────────╯          │
│                                │
│  [Daily Goal Ring]  78%        │
│                                │
│  ┌─ Per-habit cards ─────────┐ │
│  │ 🚶 Steps    8,432/10K  ✓ │ │
│  │ 🏃 Running  3.2 km     ✓ │ │
│  │ 💧 Water    1,500ml      │ │
│  │ 😴 Sleep    7.2h       ✓ │ │
│  └───────────────────────────┘ │
│                                │
│  📊 Bangalore #12 (↑3)        │
│  "142 KP to overtake @ravi"   │
│                                │
│  🎯 Daily Challenge [78%]     │
│                                │
├────────────────────────────────┤
│ 🏠  ➕  🏆  🚩  👤            │
└────────────────────────────────┘
```

---

## 12. Dark Mode Implementation Notes

### SwiftUI Color Asset Strategy

```swift
// In Colors.swift
extension Color {
    enum Klymb {
        static let backgroundPrimary = Color("BackgroundPrimary")    // Asset catalog
        static let accentPrimary = Color("AccentPrimary")            // Asset catalog
        // ... all tokens mapped to asset catalog entries
    }
}

// Usage in views
Text("1,247")
    .foregroundStyle(Color.Klymb.accentPrimary)
    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
```

Each color is defined in `Assets.xcassets` with both "Any Appearance" (light) and "Dark" variants, ensuring automatic switching.

---

## 13. Component Checklist

| Component | Defined | Accessibility | Reduce Motion | Dark/Light |
|---|---|---|---|---|
| PrimaryButton | ✅ | ✅ Label + min tap | N/A | ✅ |
| SecondaryButton | ✅ | ✅ Label + min tap | N/A | ✅ |
| Card | ✅ | ✅ Grouped | ✅ Press anim | ✅ |
| RankBadge | ✅ | ✅ Label | ✅ Scale anim | ✅ |
| ProgressRing | ✅ | ✅ Value description | ✅ Instant fill | ✅ |
| KPCounter | ✅ | ✅ Announcement | ✅ Instant change | ✅ |
| LeaderboardRow | ✅ | ✅ Combined + actions | N/A | ✅ |
| ChallengeCard | ✅ | ✅ Label + status | N/A | ✅ |
| StatTile | ✅ | ✅ Combined | N/A | ✅ |
| Toast | ✅ | ✅ Announced | ✅ Instant appear | ✅ |
| EmptyState | ✅ | ✅ Label + CTA | N/A | ✅ |
| ErrorState | ✅ | ✅ Label + CTA | N/A | ✅ |
| SkeletonLoader | ✅ | ✅ Hidden | ✅ Static | ✅ |
| Avatar | ✅ | ✅ Description | N/A | ✅ |
