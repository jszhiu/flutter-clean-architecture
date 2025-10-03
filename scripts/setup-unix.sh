#!/usr/bin/env bash
set -euo pipefail

# -------- UI helpers --------
cyan() { printf "\033[36m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }
bold() { printf "\033[1m%s\033[0m" "$1"; }

step() { echo -e "$(cyan [SETUP]) $*"; }
ok()   { echo -e "$(green [OK]) $*"; }
warn() { echo -e "$(yellow [WARN]) $*"; }

print_banner() {
  echo
  echo "$(bold "──────────────────────────────────────────────────────────────")"
  echo "$(bold "      Flutter Clean Architecture ▸ Generator (M3)")"
  echo "$(bold "──────────────────────────────────────────────────────────────")"
  echo
}

STATE_MGMT=""
APP_NAME="Clean MVVM App"
AUTO=false
PROFILE="standard" # minimal|standard|full
SKIP_INSTALL=false
SKIP_CODEGEN=false
ROUTER="" # none|go_router

usage() {
  cat <<EOF
Usage: scripts/setup-unix.sh [--state bloc|riverpod|provider|getx] [--name "App Name"] [--router go_router|none] [--profile minimal|standard|full] [--skip-install] [--skip-codegen] [--auto]

Options:
  --state    Choose state management (interactive if omitted)
  --name     Application display name (default: ${APP_NAME})
  --router   Choose router (go_router|none). Default: ask (auto: detect)
  --profile  Dependency profile (minimal|standard|full). Default: standard
  --skip-install  Do not add pub dependencies (write files only)
  --skip-codegen  Do not run build_runner/format steps
  -h, --help Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)
      STATE_MGMT=${2:-}
      shift 2
      ;;
    --name)
      APP_NAME=${2:-"${APP_NAME}"}
      shift 2
      ;;
    --profile)
      PROFILE=${2:-standard}
      shift 2
      ;;
    --router)
      ROUTER=${2:-}
      shift 2
      ;;
    --skip-install)
      SKIP_INSTALL=true
      shift 1
      ;;
    --skip-codegen)
      SKIP_CODEGEN=true
      shift 1
      ;;
    --auto)
      AUTO=true
      shift 1
      ;;
  -h|--help)
      usage; exit 0;
      ;;
    *)
      warn "Unknown arg: $1"; usage; exit 1;
      ;;
  esac
done

print_banner

if [[ "${AUTO}" == true ]]; then
  if [[ -f pubspec.yaml ]]; then
    # Detect app name
    nm=$(awk -F: '/^name:/ {print $2; exit}' pubspec.yaml | xargs || true)
    [[ -n "$nm" ]] && APP_NAME="$nm"
    # Detect state management
    if grep -q '^\s*flutter_riverpod\s*:' pubspec.yaml; then STATE_MGMT=riverpod
    elif grep -q '^\s*provider\s*:' pubspec.yaml; then STATE_MGMT=provider
    elif grep -q '^\s*get\s*:' pubspec.yaml; then STATE_MGMT=getx
    else STATE_MGMT=bloc
    fi
    # Detect router
    if grep -q '^\s*go_router\s*:' pubspec.yaml; then ROUTER=go_router; else ROUTER=none; fi
  else
    STATE_MGMT=bloc
    ROUTER=none
  fi
fi

if [[ -z "${STATE_MGMT}" ]]; then
  echo "Choose state management:";
  PS3="$(cyan '› ')"
  select sm in "BLoC/Cubit" "Riverpod" "Provider" "GetX"; do
    case $REPLY in
      1) STATE_MGMT="bloc"; break;;
      2) STATE_MGMT="riverpod"; break;;
      3) STATE_MGMT="provider"; break;;
      4) STATE_MGMT="getx"; break;;
      *) echo "Please enter 1-4";;
    esac
  done
fi

case "${STATE_MGMT}" in
  bloc|riverpod|provider|getx) ;;
  *) echo "Invalid --state: ${STATE_MGMT}. Use bloc|riverpod|provider|getx"; exit 1;;
esac

if [[ -z "${ROUTER}" && "${AUTO}" != true ]]; then
  echo "Use go_router for navigation?";
  PS3="$(cyan '› ')"
  select r in "No (Navigator)" "Yes (go_router)"; do
    case $REPLY in
      1) ROUTER="none"; break;;
      2) ROUTER="go_router"; break;;
      *) echo "Please enter 1-2";;
    esac
  done
fi

case "${ROUTER}" in
  none|go_router) ;;
  "") ROUTER=none;;
  *) echo "Invalid --router: ${ROUTER}. Use go_router|none"; exit 1;;
esac

step "Validating environment (Flutter/Dart)"
command -v flutter >/dev/null 2>&1 || { echo "Flutter not found in PATH" >&2; exit 1; }
command -v dart >/dev/null 2>&1 || { echo "Dart not found in PATH" >&2; exit 1; }

[[ -f pubspec.yaml ]] || { echo "pubspec.yaml not found. Run inside your Flutter project root." >&2; exit 1; }
if ! grep -qE '^dependencies:[[:space:]]*$' pubspec.yaml; then warn "Could not verify dependencies: section; proceeding"; fi

step "Resolving dependencies profile (${PROFILE}) for ${STATE_MGMT}"
deps="get_it dio equatable"
case "${STATE_MGMT}" in
  bloc) deps+=" flutter_bloc";;
  riverpod) deps+=" flutter_riverpod";;
  provider) deps+=" provider";;
  getx) deps+=" get";;
esac
if [[ "${PROFILE}" == "minimal" ]]; then
  deps+=" fpdart"
elif [[ "${PROFILE}" == "standard" ]]; then
  deps+=" connectivity_plus pretty_dio_logger fpdart"
else # full
  deps+=" connectivity_plus pretty_dio_logger shared_preferences flutter_secure_storage fpdart json_annotation"
fi
if [[ "${ROUTER}" == "go_router" ]]; then
  deps+=" go_router"
fi

if [[ "${SKIP_INSTALL}" == false ]]; then
  # shellcheck disable=SC2086
  dart pub add $deps
else
  warn "Skipping dependency installation (--skip-install)"
fi

step "Adding dev dependencies"
if [[ "${SKIP_INSTALL}" == false ]]; then
  if [[ "${PROFILE}" == "full" ]]; then
    dart pub add -d flutter_lints build_runner json_serializable
  elif [[ "${PROFILE}" == "standard" ]]; then
    dart pub add -d flutter_lints
  else
    warn "Skipping dev dependencies for minimal profile"
  fi
fi

step "Creating folders"
dirs=(
  lib/src/core/constants
  lib/src/core/di
  lib/src/core/error
  lib/src/core/network
  lib/src/core/usecase
  lib/src/features/todo/domain/entities
  lib/src/features/todo/domain/repositories
  lib/src/features/todo/domain/usecases
  lib/src/features/todo/data/models
  lib/src/features/todo/data/datasources
  lib/src/features/todo/data/repositories
  lib/src/features/todo/presentation/cubit
  lib/src/features/todo/presentation/pages
)
mkdir -p "${dirs[@]}"

step "Writing analysis options"
cat > analysis_options.yaml << 'EOF'
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    always_use_package_imports: true
    avoid_print: true
    prefer_single_quotes: true
    cascade_invocations: true
    directives_ordering: true
    eol_at_end_of_file: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    require_trailing_commas: true
EOF

step "Writing core files"
cat > lib/src/core/constants/app_constants.dart << 'EOF'
class AppConstants {
  static const appName = 'APP_NAME_PLACEHOLDER';
  static const apiBaseUrl = 'https://jsonplaceholder.typicode.com';
}
EOF

cat > lib/src/core/error/failures.dart << 'EOF'
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure([this.message = '']);
  final String message;
  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure { const NetworkFailure([super.message]); }
class ServerFailure extends Failure { const ServerFailure([super.message]); }
class CacheFailure extends Failure { const CacheFailure([super.message]); }
EOF

cat > lib/src/core/error/exceptions.dart << 'EOF'
class ServerException implements Exception {
  ServerException([this.message = 'Server error', this.code]);
  final String message; final int? code;
  @override String toString() => 'ServerException(code: $code, message: $message)';
}
class NetworkException implements Exception {
  NetworkException([this.message = 'No internet connection']);
  final String message; @override String toString() => 'NetworkException(message: $message)';
}
EOF

cat > lib/src/core/network/network_info.dart << 'EOF'
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo { Future<bool> get isConnected; }
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);
  final Connectivity _connectivity;
  @override Future<bool> get isConnected async => (await _connectivity.checkConnectivity()) != ConnectivityResult.none;
}
EOF

cat > lib/src/core/network/dio_client.dart << 'EOF'
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/app_constants.dart';

class DioClient {
  DioClient(this._dio) {
    _dio
      ..options.baseUrl = AppConstants.apiBaseUrl
      ..options.connectTimeout = const Duration(seconds: 20)
      ..options.receiveTimeout = const Duration(seconds: 20)
      ..interceptors.add(PrettyDioLogger(requestBody: true, responseBody: false));
  }
  final Dio _dio; Dio get instance => _dio;
}
EOF

cat > lib/src/core/theme/app_theme.dart << 'EOF'
import 'package:flutter/material.dart';

final _lightSeed = const Color(0xFF4F46E5); // Indigo
final _darkSeed = const Color(0xFF22D3EE);  // Cyan

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _lightSeed, brightness: Brightness.light);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _darkSeed, brightness: Brightness.dark);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface, elevation: 0),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
  );
}

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({super.key, required this.appBar, required this.child});
  final PreferredSizeWidget appBar; final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(.10), cs.secondary.withOpacity(.08)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: child,
      ),
    );
  }
}
EOF

if [[ "${ROUTER}" == "go_router" ]]; then
  step "Writing router (go_router)"
  mkdir -p lib/src/core/router
  cat > lib/src/core/router/app_router.dart << 'EOF'
import 'package:go_router/go_router.dart';
import '../../features/todo/presentation/pages/todo_list_page.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const TodoListPage()),
  ],
);
EOF
fi

cat > lib/src/core/usecase/usecase.dart << 'EOF'
import 'package:fpdart/fpdart.dart';
import '../error/failures.dart';

abstract class UseCase<T, P> { Future<Either<Failure, T>> call(P params); }
class NoParams { const NoParams(); }
EOF

step "Writing DI"
cat > lib/src/core/di/injection.dart << 'EOF'
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../../features/todo/data/datasources/todo_remote_data_source.dart';
import '../../features/todo/data/repositories/todo_repository_impl.dart';
import '../../features/todo/domain/repositories/todo_repository.dart';
import '../../features/todo/domain/usecases/get_todos.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton(() => DioClient(sl()));

  // Features - Todo
  sl.registerLazySingleton<TodoRemoteDataSource>(() => TodoRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<TodoRepository>(() => TodoRepositoryImpl(remote: sl(), networkInfo: sl()));
  sl.registerFactory(() => GetTodos(sl()));
}
EOF

step "Writing feature: Todo (domain)"
cat > lib/src/features/todo/domain/entities/todo.dart << 'EOF'
import 'package:equatable/equatable.dart';

class Todo extends Equatable {
  const Todo({required this.id, required this.title, required this.completed});
  final int id; final String title; final bool completed;
  @override List<Object?> get props => [id, title, completed];
}
EOF

cat > lib/src/features/todo/domain/repositories/todo_repository.dart << 'EOF'
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo.dart';

abstract class TodoRepository { Future<Either<Failure, List<Todo>>> getTodos(); }
EOF

cat > lib/src/features/todo/domain/usecases/get_todos.dart << 'EOF'
import 'package:fpdart/fpdart.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

class GetTodos implements UseCase<List<Todo>, NoParams> {
  GetTodos(this._repository);
  final TodoRepository _repository;
  @override Future<Either<Failure, List<Todo>>> call(NoParams params) => _repository.getTodos();
}
EOF

step "Writing feature: Todo (data)"
cat > lib/src/features/todo/data/models/todo_model.dart << 'EOF'
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/todo.dart';

part 'todo_model.g.dart';

@JsonSerializable()
class TodoModel {
  const TodoModel({required this.id, required this.title, required this.completed});
  factory TodoModel.fromJson(Map<String, dynamic> json) => _$TodoModelFromJson(json);
  final int id; final String title; final bool completed;
  Map<String, dynamic> toJson() => _$TodoModelToJson(this);
  Todo toEntity() => Todo(id: id, title: title, completed: completed);
}
EOF

cat > lib/src/features/todo/data/datasources/todo_remote_data_source.dart << 'EOF'
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/error/exceptions.dart';
import '../models/todo_model.dart';

abstract class TodoRemoteDataSource { Future<List<TodoModel>> getTodos(); }

class TodoRemoteDataSourceImpl implements TodoRemoteDataSource {
  TodoRemoteDataSourceImpl(this._client);
  final DioClient _client;
  @override Future<List<TodoModel>> getTodos() async {
    try {
      final resp = await _client.instance.get<List<dynamic>>('/todos');
      final data = resp.data ?? [];
      return data.map((e) => TodoModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) { throw ServerException(e.message ?? 'Dio error', e.response?.statusCode); }
  }
}
EOF

cat > lib/src/features/todo/data/repositories/todo_repository_impl.dart << 'EOF'
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_remote_data_source.dart';

class TodoRepositoryImpl implements TodoRepository {
  TodoRepositoryImpl({required TodoRemoteDataSource remote, required NetworkInfo networkInfo})
      : _remote = remote, _networkInfo = networkInfo;
  final TodoRemoteDataSource _remote; final NetworkInfo _networkInfo;
  @override Future<Either<Failure, List<Todo>>> getTodos() async {
    if (!await _networkInfo.isConnected) return left(const NetworkFailure('No internet connection'));
    try { final models = await _remote.getTodos(); return right(models.map((m) => m.toEntity()).toList()); }
    on ServerException catch (e) { return left(ServerFailure(e.message)); }
    catch (e) { return left(ServerFailure(e.toString())); }
  }
}
EOF

step "Writing feature: Todo (presentation) for ${STATE_MGMT}"

case "${STATE_MGMT}" in
  bloc)
    mkdir -p lib/src/features/todo/presentation/cubit lib/src/features/todo/presentation/pages
    cat > lib/src/features/todo/presentation/cubit/todo_list_state.dart << 'EOF'
import 'package:equatable/equatable.dart';

enum ViewStatus { idle, loading, success, error }

class TodoListState extends Equatable {
  const TodoListState({this.status = ViewStatus.idle, this.items = const [], this.error});
  final ViewStatus status; final List<dynamic> items; final String? error;
  TodoListState copyWith({ViewStatus? status, List<dynamic>? items, String? error}) =>
      TodoListState(status: status ?? this.status, items: items ?? this.items, error: error);
  @override List<Object?> get props => [status, items, error];
}
EOF

    cat > lib/src/features/todo/presentation/cubit/todo_list_cubit.dart << 'EOF'
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/get_todos.dart';
import 'todo_list_state.dart';

class TodoListCubit extends Cubit<TodoListState> {
  TodoListCubit(this._getTodos) : super(const TodoListState());
  final GetTodos _getTodos;
  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _getTodos(const NoParams());
    result.match(
      (l) => emit(state.copyWith(status: ViewStatus.error, items: const [], error: l.message)),
      (r) => emit(state.copyWith(status: ViewStatus.success, items: r, error: null)),
    );
  }
}
EOF

    cat > lib/src/features/todo/presentation/pages/todo_list_page.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../domain/usecases/get_todos.dart';
import '../cubit/todo_list_cubit.dart';
import '../cubit/todo_list_state.dart';

class TodoListPage extends StatelessWidget {
  const TodoListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TodoListCubit(sl<GetTodos>())..load(),
      child: GradientScaffold(
        appBar: AppBar(title: const Text('Todos')),
        child: BlocBuilder<TodoListCubit, TodoListState>(
          builder: (context, state) {
            switch (state.status) {
              case ViewStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ViewStatus.error:
                return Center(child: _ErrorView(message: state.error ?? 'Something went wrong'));
              case ViewStatus.success:
                return _TodoList(items: state.items);
              case ViewStatus.idle:
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.items});
  final List<dynamic> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final todo = items[i];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (todo.completed as bool) ? cs.primaryContainer : cs.surfaceVariant,
                child: Icon(
                  (todo.completed as bool) ? Icons.check_rounded : Icons.circle_outlined,
                  color: (todo.completed as bool) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
              title: Text(todo.title as String),
              subtitle: Text('ID: ${todo.id}'),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 48),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
EOF
    ;;
  riverpod)
    mkdir -p lib/src/features/todo/presentation/providers lib/src/features/todo/presentation/pages
    cat > lib/src/features/todo/presentation/providers/todo_list_provider.dart << 'EOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/usecases/get_todos.dart';

final getTodosProvider = Provider<GetTodos>((_) => sl<GetTodos>());

final todoListProvider = StateNotifierProvider<TodoListNotifier, AsyncValue<List<Todo>>>(
  (ref) => TodoListNotifier(ref.read(getTodosProvider))..load(),
);

class TodoListNotifier extends StateNotifier<AsyncValue<List<Todo>>> {
  TodoListNotifier(this._getTodos) : super(const AsyncValue.loading());
  final GetTodos _getTodos;
  Future<void> load() async {
    state = const AsyncLoading();
    final res = await _getTodos(const NoParams());
    state = res.match(
      (l) => AsyncError(l.message, StackTrace.current),
      (r) => AsyncData(r),
    );
  }
}
EOF

    cat > lib/src/features/todo/presentation/pages/todo_list_page.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/todo_list_provider.dart';

class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todoListProvider);
    return GradientScaffold(
      appBar: AppBar(title: const Text('Todos')),
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorView(message: e.toString())),
        data: (items) => _TodoList(items: items),
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.items});
  final List<dynamic> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final todo = items[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (todo.completed as bool) ? cs.primaryContainer : cs.surfaceVariant,
              child: Icon(
                (todo.completed as bool) ? Icons.check_rounded : Icons.circle_outlined,
                color: (todo.completed as bool) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
            title: Text(todo.title as String),
            subtitle: Text('ID: ${todo.id}'),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 48),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
EOF
    ;;
  provider)
    mkdir -p lib/src/features/todo/presentation/notifier lib/src/features/todo/presentation/pages
    cat > lib/src/features/todo/presentation/notifier/todo_list_notifier.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/usecases/get_todos.dart';

enum ViewStatus { idle, loading, success, error }

class TodoListNotifier extends ChangeNotifier {
  TodoListNotifier(this._getTodos);
  final GetTodos _getTodos;
  ViewStatus status = ViewStatus.idle;
  List<Todo> items = const [];
  String? error;

  Future<void> load() async {
    status = ViewStatus.loading; notifyListeners();
    final res = await _getTodos(const NoParams());
    res.match(
      (l) { status = ViewStatus.error; items = const []; error = l.message; notifyListeners(); },
      (r) { status = ViewStatus.success; items = r; error = null; notifyListeners(); },
    );
  }
}
EOF

    cat > lib/src/features/todo/presentation/pages/todo_list_page.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../domain/usecases/get_todos.dart';
import '../notifier/todo_list_notifier.dart';

class TodoListPage extends StatelessWidget {
  const TodoListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TodoListNotifier(sl<GetTodos>())..load(),
      child: GradientScaffold(
        appBar: AppBar(title: const Text('Todos')),
        child: Consumer<TodoListNotifier>(
          builder: (context, vm, _) {
            switch (vm.status) {
              case ViewStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ViewStatus.error:
                return Center(child: _ErrorView(message: vm.error ?? 'Something went wrong'));
              case ViewStatus.success:
                return _TodoList(items: vm.items);
              case ViewStatus.idle:
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.items});
  final List<dynamic> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final todo = items[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (todo.completed as bool) ? cs.primaryContainer : cs.surfaceVariant,
              child: Icon(
                (todo.completed as bool) ? Icons.check_rounded : Icons.circle_outlined,
                color: (todo.completed as bool) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
            title: Text(todo.title as String),
            subtitle: Text('ID: ${todo.id}'),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 48),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
EOF
    ;;
  getx)
    mkdir -p lib/src/features/todo/presentation/controller lib/src/features/todo/presentation/pages
    cat > lib/src/features/todo/presentation/controller/todo_controller.dart << 'EOF'
import 'package:get/get.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/todo.dart';
import '../../domain/usecases/get_todos.dart';

class TodoController extends GetxController {
  final items = <Todo>[].obs;
  final loading = false.obs;
  final error = RxnString();
  final _getTodos = sl<GetTodos>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true; error.value = null; items.clear();
    final res = await _getTodos(const NoParams());
    res.match(
      (l) => error.value = l.message,
      (r) => items.assignAll(r),
    );
    loading.value = false;
  }
}
EOF

    cat > lib/src/features/todo/presentation/pages/todo_list_page.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../controller/todo_controller.dart';

class TodoListPage extends StatelessWidget {
  const TodoListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.put(TodoController());
    return GradientScaffold(
      appBar: AppBar(title: const Text('Todos')),
      child: Obx(() {
        if (c.loading.value) return const Center(child: CircularProgressIndicator());
        if (c.error.value != null) return Center(child: _ErrorView(message: c.error.value!));
        return _TodoList(items: c.items);
      }),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({required this.items});
  final List<dynamic> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final todo = items[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (todo.completed as bool) ? cs.primaryContainer : cs.surfaceVariant,
              child: Icon(
                (todo.completed as bool) ? Icons.check_rounded : Icons.circle_outlined,
                color: (todo.completed as bool) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
            title: Text(todo.title as String),
            subtitle: Text('ID: ${todo.id}'),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 48),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
EOF
    ;;
esac

step "Writing app and main.dart"
if [[ "${ROUTER}" == "go_router" ]]; then
  # Use MaterialApp.router for all variants when go_router is selected
  cat > lib/src/app.dart << 'EOF'
import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: appRouter,
    );
  }
}
EOF
else
  case "${STATE_MGMT}" in
    bloc|riverpod|provider)
      cat > lib/src/app.dart << 'EOF'
import 'package:flutter/material.dart';
import 'features/todo/presentation/pages/todo_list_page.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const TodoListPage(),
    );
  }
}
EOF
      ;;
    getx)
      cat > lib/src/app.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'features/todo/presentation/pages/todo_list_page.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const TodoListPage(),
    );
  }
}
EOF
      ;;
  esac
fi

if [[ "${STATE_MGMT}" == "riverpod" ]]; then
  cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const ProviderScope(child: App()));
}
EOF
else
  cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const App());
}
EOF
fi

if [[ "${SKIP_CODEGEN}" == false && "${PROFILE}" == "full" && "${SKIP_INSTALL}" == false ]]; then
  step "Running code generation"
  dart run build_runner build --delete-conflicting-outputs >/dev/null || warn "build_runner failed (you can rerun later)"
fi

if [[ "${SKIP_CODEGEN}" == false ]]; then
  step "Formatting Dart files"
  dart format lib >/dev/null || true
fi

perl -pi -e "s/APP_NAME_PLACEHOLDER/\Q${APP_NAME}\E/g" lib/src/core/constants/app_constants.dart

ok "Clean Architecture scaffolded with (${STATE_MGMT})."
echo "Run: flutter run -d windows|macos|linux (or any device)"
