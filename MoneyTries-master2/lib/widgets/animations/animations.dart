// lib/widgets/animations/animations.dart
//
// Barrel export for the app-wide animation toolkit. Import this single
// file wherever you need premium motion primitives:
//
//   import '../../widgets/animations/animations.dart';
//
export 'app_page_route.dart';
export 'shimmer_network_image.dart';
export 'count_up_text.dart';
export 'animated_tap_scale.dart';
export 'staggered_entrance.dart';
export 'success_check_animation.dart';
export 'animated_primary_button.dart';
export 'animated_nav_icon.dart';

/// Shared Hero tag for the small circular profile-avatar shown in each
/// screen's top bar (Home, Deposit, Withdrawal, etc.) so tapping through
/// to Profile flies the avatar smoothly between screens instead of a
/// hard cut. Kept distinct from Profile screen's own large-avatar hero
/// tag so the two never collide.
const String kAppTopbarAvatarHeroTag = 'app-topbar-avatar-hero';