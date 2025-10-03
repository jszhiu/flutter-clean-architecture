Flutter Clean Architecture (MVVM + BLoC + Dio)

<p align="center">
  <em>One-command scaffold for a pragmatic clean Flutter stack.</em>
</p>

<p align="center">
  <a href="https://github.com/Amir-beigi-84/flutter-clean-architecture/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/Amir-beigi-84/flutter-clean-architecture?style=flat-square&color=ffc83d">
  </a>
  <a href="https://github.com/Amir-beigi-84/flutter-clean-architecture/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/Amir-beigi-84/flutter-clean-architecture?style=flat-square">
  </a>
  <img alt="Last Commit" src="https://img.shields.io/github/last-commit/Amir-beigi-84/flutter-clean-architecture?style=flat-square">
  <img alt="License" src="https://img.shields.io/github/license/Amir-beigi-84/flutter-clean-architecture?style=flat-square">
  <img alt="PRs Welcome" src="https://img.shields.io/badge/PRs-welcome-28a745?style=flat-square">
</p>

Quick Start

- Create app: `flutter create my_app && cd my_app`
- Copy this repo’s `scripts/` into your project (or clone and run from inside your app).
- Run one setup script from your project root:
  - Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1`
  - macOS/Linux (Bash/Zsh): `chmod +x scripts/setup-unix.sh && scripts/setup-unix.sh`
  - fish: `chmod +x scripts/setup-fish.fish && fish scripts/setup-fish.fish`

What You Get

- Dependencies wired: `get_it`, `flutter_bloc`, `dio`, `fpdart`, `equatable`, `connectivity_plus`, `json_*`.
- Clean layers scaffolded under `lib/src/` with a sample `todo` feature.
- DI (`get_it`), `Dio` client with logging, and `build_runner` codegen.
- Minimal `main.dart` bootstrap and formatted code.

Run

- `flutter run -d windows|macos|linux` (or any device)

