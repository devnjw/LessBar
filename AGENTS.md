# LessBar product principles

User-confirmed direction: LessBar is an extremely simple, minimal menu bar utility.

- Prefer intuitive controls, whitespace and a small visual example over explanatory text.
- Keep only essential settings. Do not add marketing copy, numbered onboarding, repeated instructions, version footers or duplicate actions to the main settings view.
- Keep instructional illustrations visually separate from real controls; examples must not look like draggable or clickable controls. Use explicit action labels rather than ambiguous icon-only buttons in settings.
- Keep visibility controls synchronized with the actual menu bar engine, including recovery.
- Show LessBar in Dock and ⌘Tab while Settings is open, including when minimized or inactive. Return to menu-bar-only mode when Settings closes.
- Timing expands and collapses smoothly from the bottom while the window's top stays fixed. Keep window sizing separate from the disclosure's intrinsic-height animation to avoid jitter; respect Reduce Motion.
- Hover requires automatic hiding: show Automatically Hide as on and disabled with a brief explanation. Keep the user's previous automatic-hide choice for when hover is turned off, including across relaunches; keep the hide delay adjustable.
- Keep Show Icons / Hide Icons out of both settings and menus. Only Quit has an app shortcut (⌘Q); Settings has none. Preserve native keyboard navigation and reopen-to-reveal recovery.
- Show the chevron when hover is off or Accessibility permission is missing. Hide it when hover is enabled with permission, including collapsed recovery panels; retain empty-space right-click menus and reopen recovery. Command editing temporarily shows boundaries. The rounded bar-and-dot LESS mark is the brand logo.
- Follow macOS native menu UI conventions. Use standard NSMenu / NSMenuItem for the settings/quit menu; let the system control spacing, typography, highlighting and keyboard behavior. Do not replace menus with custom popovers or add blank items for padding. This takes priority over custom menu spacing preferences.
- Keep active screen-sharing indicators visible and clickable. Prefer them to the right of the chevron, but do not claim guaranteed expanded-state ordering without a verified implementation. Do not cover system indicators or move the hide boundary to a different group just to mimic this order.
- Preserve keyboard access, accessibility labels and necessary error/unsupported-state feedback. Minimalism must not remove recovery or hide failures.
- Brand: LessBar. Audience: global individual Mac users. Target price: US $0.99 one-time. Early promotion: free coupons. No extra tiers or feature expansion without a user request.
- Publication decision (2026-10-11): public GitHub repository under devnjw with the MIT license. Initial GitHub previews are free; do not imply an implemented paid checkout. Keep installation instructions in English and Korean and distinguish notarized releases from development builds.

These preferences should guide future design and implementation in this repository.
