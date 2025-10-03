Flutter Clean Architecture

<p align="center">
  <em>MVVM + BLoC + Dio — a pragmatic, one-command Flutter scaffold.</em>
  <br/>
  <img alt="Flutter Clean" src="https://img.shields.io/badge/Flutter-Clean%20Architecture-02569B?logo=flutter&logoColor=white&style=for-the-badge">
  <a href="https://github.com/Amir-beigi-84/flutter-clean-architecture/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/Amir-beigi-84/flutter-clean-architecture?style=for-the-badge&color=FFC83D">
  </a>
  <a href="https://github.com/Amir-beigi-84/flutter-clean-architecture/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/Amir-beigi-84/flutter-clean-architecture?style=for-the-badge&color=FF5A5F">
  </a>
  <img alt="License" src="https://img.shields.io/github/license/Amir-beigi-84/flutter-clean-architecture?style=for-the-badge&color=4CAF50">
</p>

Quick Start

- Create app: `flutter create my_app && cd my_app`
- Copy `scripts/` from this repo into your project.
- Run one setup script from your project root:
  - Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File scripts\\setup-windows.ps1`
  - macOS/Linux (Bash/Zsh): `chmod +x scripts/setup-unix.sh && scripts/setup-unix.sh`
  - fish: `chmod +x scripts/setup-fish.fish && fish scripts/setup-fish.fish`

What You Get

- Batteries-included deps: `get_it`, `flutter_bloc`, `dio`, `fpdart`, `equatable`, `connectivity_plus`, `json_*`.
- Clean layers under `lib/src/` with a sample `todo` feature.
- DI setup (`get_it`), `Dio` client + logging, `build_runner` codegen.
- Minimal `main.dart` bootstrap and opinionated lints.

Run

- `flutter run -d windows|macos|linux` (or any device)

Stack

- Architecture: MVVM + Clean layers
- State: `flutter_bloc`
- Networking: `dio` + `pretty_dio_logger`
- DI: `get_it`
- Functional core: `fpdart`

Why

- Ship a clean baseline fast without yak-shaving.
- Consistent structure for multi-feature apps.
- Easy to tear out or extend pieces as you go.

Code Snippets

Entity

```dart
// lib/src/features/todo/domain/entities/todo.dart
import 'package:equatable/equatable.dart';

class Todo extends Equatable {
  const Todo({required this.id, required this.title, required this.completed});
  final int id;
  final String title;
  final bool completed;
  @override
  List<Object?> get props => [id, title, completed];
}
```

Use Case

```dart
// lib/src/features/todo/domain/usecases/get_todos.dart
import 'package:fpdart/fpdart.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

class GetTodos implements UseCase<List<Todo>, NoParams> {
  GetTodos(this._repository);
  final TodoRepository _repository;
  @override
  Future<Either<Failure, List<Todo>>> call(NoParams params) => _repository.getTodos();
}
```

Repository

```dart
// lib/src/features/todo/domain/repositories/todo_repository.dart
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo.dart';

abstract class TodoRepository {
  Future<Either<Failure, List<Todo>>> getTodos();
}
```

Repository Impl

```dart
// lib/src/features/todo/data/repositories/todo_repository_impl.dart
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_remote_data_source.dart';

class TodoRepositoryImpl implements TodoRepository {
  TodoRepositoryImpl({required this.remote, required this.networkInfo});
  final TodoRemoteDataSource remote;
  final NetworkInfo networkInfo;

  @override
  Future<Either<Failure, List<Todo>>> getTodos() async {
    if (!await networkInfo.isConnected) {
      return left(const NetworkFailure('No internet connection'));
    }
    try {
      final result = await remote.getTodos();
      return right(result);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } catch (_) {
      return left(const ServerFailure('Unexpected error'));
    }
  }
}
```

Cubit (Presentation)

```dart
// lib/src/features/todo/presentation/cubit/todo_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/usecases/get_todos.dart';

sealed class TodoState {}
class TodoInitial extends TodoState {}
class TodoLoading extends TodoState {}
class TodoLoaded extends TodoState { TodoLoaded(this.items); final List<Todo> items; }
class TodoError extends TodoState { TodoError(this.message); final String message; }

class TodoCubit extends Cubit<TodoState> {
  TodoCubit(this._getTodos) : super(TodoInitial());
  final GetTodos _getTodos;

  Future<void> load() async {
    emit(TodoLoading());
    final res = await _getTodos(const NoParams());
    res.match(
      (l) => emit(TodoError(l.message)),
      (r) => emit(TodoLoaded(r)),
    );
  }
}
```

Bootstrap

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'src/core/di/injection.dart';
import 'src/features/todo/presentation/cubit/todo_cubit.dart';
import 'src/features/todo/domain/usecases/get_todos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean MVVM App',
      home: BlocProvider(
        create: (_) => TodoCubit(sl<GetTodos>())..load(),
        child: const Scaffold(
          appBar: AppBar(title: Text('Todos')),
          body: Center(child: Text('…')), // Replace with your UI
        ),
      ),
    );
  }
}
```
