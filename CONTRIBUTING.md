# Contributing to Artha Network iOS

## Setup

```bash
git clone git@github.com:YOUR_ORG/artha-ios-app.git
cd artha-ios-app
make setup      # installs XcodeGen via Homebrew
make open       # generates project + opens Xcode
```

Swift packages (swift-sodium) resolve automatically on first build.

Never commit `ArthaNetwork.xcodeproj/` — it is gitignored. Run `make generate` after pulling changes to `project.yml`.

## Branch naming

```
feat/short-description
fix/short-description
chore/short-description
```

Example: `feat/push-notifications`, `fix/evidence-upload-heic`

## Commit style

Use the conventional commit prefix that best fits:

| Prefix | Use for |
|---|---|
| `feat:` | New user-facing feature |
| `fix:` | Bug fix |
| `refactor:` | Internal restructure, no behaviour change |
| `chore:` | Tooling, config, dependency updates |
| `docs:` | Documentation only |

Keep the subject line under 72 characters. Add a body if the *why* needs explanation.

```
fix: load photo as Data before UIImage to fix HEIC upload

UIImage does not conform to Transferable. Load raw Data via
loadTransferable(type: Data.self) then decode with UIImage(data:).
```

## Pull request checklist

- [ ] `make generate` run after any `project.yml` change
- [ ] Project builds cleanly (`Cmd+B`, no warnings added)
- [ ] No new secrets, API keys, or personal credentials in source
- [ ] No `ArthaNetwork.xcodeproj/` changes staged
- [ ] `AppConfiguration.swift` updated if new environment variables are added
- [ ] `README.md` / `STATUS.md` updated if feature status changes
- [ ] SwiftUI previews work for any new views (or are clearly marked `#if DEBUG`)

## Code conventions

- **MVVM**: Views own `@State private var viewModel = SomeViewModel()`. ViewModels are `@Observable final class`.
- **No SwiftUI in ViewModels**: ViewModels must not import SwiftUI. Pass UI-layer types (e.g. `UIImage`) as parameters, not `PhotosPickerItem` or `View`.
- **Async/await**: All network calls are `async throws`. Call sites use `Task { await … }` inside `.task {}` or button actions.
- **Error handling**: Set `viewModel.error: String?` for user-visible errors. Do not use `fatalError` outside existing stubs.
- **No hardcoded URLs or secrets**: All config goes through `AppConfiguration.swift` via environment variables.
- **Minimal changes**: Fix the stated issue. Do not refactor surrounding code or add speculative abstractions.
