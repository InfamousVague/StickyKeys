# Code Style

- Follow the project's existing patterns and conventions
- Keep functions focused and small
- Prefer explicit over implicit
- Write self-documenting code — add comments only where logic isn't self-evident
- UI state lives in `LockStore` (`@MainActor`, `@Observable`); views stay declarative.
- Event-tap / CoreGraphics plumbing is confined to `KeyboardLock`.
- Safety first: there must ALWAYS be a mouse-only way out (overlay button +
  menu-bar item) and a safety auto-unlock timer. Never gate unlock behind the
  keyboard. The tap is torn down completely on unlock — no lingering hooks.
