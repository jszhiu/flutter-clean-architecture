Clean Architecture (MVVM + BLoC + Dio) — Cross‑Platform Setup

![Visitors](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https://github.com/Amir-beigi-84/flutter-clean-architecture&count_bg=%2379C83D&title_bg=%23555555&icon=flutter.svg&icon_color=%23FFFFFF&title=visits&edge_flat=false)
![GitHub stars](https://img.shields.io/github/stars/Amir-beigi-84/flutter-clean-architecture?style=social)
![GitHub forks](https://img.shields.io/github/forks/Amir-beigi-84/flutter-clean-architecture?style=social)
![Open Issues](https://img.shields.io/github/issues/Amir-beigi-84/flutter-clean-architecture)
![Last Commit](https://img.shields.io/github/last-commit/Amir-beigi-84/flutter-clean-architecture)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

Scripts by Platform

- Windows (PowerShell): `scripts\\setup-windows.ps1`
- macOS/Linux (Bash/Zsh): `scripts/setup-unix.sh`
- Linux/macOS (fish): `scripts/setup-fish.fish`

Usage

- Create your Flutter app first:
  - Run: `flutter create my_app`
  - `cd my_app`
- Windows (PowerShell):
  - `powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1`
- macOS/Linux (Bash/Zsh):
  - `chmod +x ./scripts/setup-unix.sh`
  - `./scripts/setup-unix.sh`
- Linux fish shell (also works on macOS fish):
  - `chmod +x ./scripts/setup-fish.fish`
  - `fish ./scripts/setup-fish.fish`

What this does

- Adds dependencies: `get_it`, `flutter_bloc`, `dio`, `fpdart`, `equatable`, `connectivity_plus`, `json_annotation`, etc.
- Creates clean layers: `data`, `domain`, `presentation` under `lib/src/features/<feature>`.
- Adds DI (`get_it`) and network client with `dio` + logging interceptor.
- Scaffolds a sample `Todo` feature, BLoC as ViewModel (MVVM style), and a simple UI page.
- Replaces the Flutter counter template `lib/main.dart` with a minimal bootstrap.
- Runs `build_runner` for JSON codegen and formats code.

Reference

- Based on and aligned with: https://medium.com/@yamen.abd98/clean-architecture-in-flutter-mvvm-bloc-dio-79b1615530e1 (with some pragmatic improvements for Windows dev flow).

Next steps

- Run: `flutter run -d windows|macos|linux` (or any device)
- Add more features under `lib/src/features/<your_feature>` following the same pattern.
