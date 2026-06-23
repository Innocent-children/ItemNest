export function shouldShowRecentSection(preferenceEnabled: boolean, recentItemCount: number): boolean {
  return preferenceEnabled || recentItemCount > 0;
}
