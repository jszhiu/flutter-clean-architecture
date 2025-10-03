$ErrorActionPreference = 'Stop'

param(
  [string]$state = '',
  [string]$name = 'Clean MVVM App',
  [switch]$auto,
  [ValidateSet('minimal','standard','full')] [string]$profile = 'standard',
  [switch]$SkipInstall,
  [switch]$SkipCodegen,
  [ValidateSet('go_router','none','')] [string]$router = ''
)

# Support double-dash args as well
for ($i = 0; $i -lt $args.Count; $i++) {
  switch ($args[$i]) {
    '--state' { if ($i + 1 -lt $args.Count) { $state = $args[$i+1]; $i++ } }
    '--name'  { if ($i + 1 -lt $args.Count) { $name = $args[$i+1];  $i++ } }
    '--auto'  { $auto = $true }
    '--profile' { if ($i + 1 -lt $args.Count) { $profile = $args[$i+1]; $i++ } }
    '--skip-install' { $SkipInstall = $true }
    '--skip-codegen' { $SkipCodegen = $true }
    '--router' { if ($i + 1 -lt $args.Count) { $router = $args[$i+1]; $i++ } }
  }
}

function Write-Step($msg) { Write-Host "[SETUP] $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Show-Banner {
  Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
  Write-Host "      Flutter Clean Architecture ▸ Generator (M3)"
  Write-Host "──────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

Show-Banner

if ($auto) {
  if (Test-Path 'pubspec.yaml') {
    $line = (Select-String -Path 'pubspec.yaml' -Pattern '^name:\s*(.+)$' -AllMatches | Select-Object -First 1)
    if ($line) { $name = ($line.Matches[0].Groups[1].Value).Trim() }
    $deps = Get-Content -Raw 'pubspec.yaml'
    if ($deps -match 'flutter_riverpod\s*:') { $state = 'riverpod' }
    elseif ($deps -match '\n\s*provider\s*:') { $state = 'provider' }
    elseif ($deps -match '\n\s*get\s*:') { $state = 'getx' }
    else { $state = 'bloc' }
    if ((Select-String -Path 'pubspec.yaml' -Pattern '^\s*go_router\s*:' -AllMatches)) { $router = 'go_router' } else { $router = 'none' }
  } else {
    $state = 'bloc'
    $router = 'none'
  }
}

if (-not $state) {
  Write-Host "Choose state management:" -ForegroundColor Cyan
  Write-Host "  1) BLoC/Cubit"
  Write-Host "  2) Riverpod"
  Write-Host "  3) Provider"
  Write-Host "  4) GetX"
  do {
    $sel = Read-Host '› Enter 1-4'
  } until ($sel -in '1','2','3','4')
  $state = @('bloc','riverpod','provider','getx')[[int]$sel-1]
}

if ($state -notin 'bloc','riverpod','provider','getx') { throw "Invalid --state: $state" }

Write-Step 'Validating environment (Flutter/Dart)'
try { & flutter --version | Out-Null } catch { throw 'Flutter is not available in PATH.' }
try { & dart --version | Out-Null } catch { throw 'Dart is not available in PATH.' }

if (!(Test-Path 'pubspec.yaml')) { throw 'pubspec.yaml not found. Run this script inside your Flutter project root.' }
if (-not (Select-String -Path 'pubspec.yaml' -Pattern '^dependencies:\s*\n\s*flutter:' -SimpleMatch:$false)) {
  Write-Warn 'This does not look like a Flutter app (no flutter: under dependencies). Proceeding anyway.'
}

Write-Step "Resolving dependencies profile ($profile) for $state"
$deps = @('get_it','dio','equatable')
switch ($state) {
  'bloc'     { $deps += 'flutter_bloc' }
  'riverpod' { $deps += 'flutter_riverpod' }
  'provider' { $deps += 'provider' }
  'getx'     { $deps += 'get' }
}
if ($profile -ne 'minimal') { $deps += @('connectivity_plus','pretty_dio_logger') }
if ($profile -eq 'full') { $deps += @('shared_preferences','flutter_secure_storage','fpdart','json_annotation') }
if ($profile -eq 'minimal') { $deps += 'fpdart' }
if ($router -eq 'go_router') { $deps += 'go_router' }

if (-not $SkipInstall) { & dart pub add @deps } else { Write-Warn 'Skipping dependency installation (--skip-install)' }

Write-Step 'Adding dev dependencies'
if (-not $SkipInstall) {
  switch ($profile) {
    'full' { & dart pub add -d flutter_lints build_runner json_serializable }
    'standard' { & dart pub add -d flutter_lints }
    default { Write-Warn 'Skipping dev dependencies for minimal profile' }
  }
}

Write-Step 'Creating folders'
$dirs = @(
  'lib/src/core/constants','lib/src/core/di','lib/src/core/error','lib/src/core/network','lib/src/core/usecase','lib/src/core/theme',
  'lib/src/features/todo/domain/entities','lib/src/features/todo/domain/repositories','lib/src/features/todo/domain/usecases',
  'lib/src/features/todo/data/models','lib/src/features/todo/data/datasources','lib/src/features/todo/data/repositories'
)
switch ($state) {
  'bloc'     { $dirs += @('lib/src/features/todo/presentation/cubit','lib/src/features/todo/presentation/pages') }
  'riverpod' { $dirs += @('lib/src/features/todo/presentation/providers','lib/src/features/todo/presentation/pages') }
  'provider' { $dirs += @('lib/src/features/todo/presentation/notifier','lib/src/features/todo/presentation/pages') }
  'getx'     { $dirs += @('lib/src/features/todo/presentation/controller','lib/src/features/todo/presentation/pages') }
}
foreach ($d in $dirs) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

Write-Step 'Writing analysis options'
@'
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
'@ | Set-Content -Encoding utf8 'analysis_options.yaml'

Write-Step 'Writing core files'
@'
class AppConstants {
  static const appName = 'APP_NAME_PLACEHOLDER';
  static const apiBaseUrl = 'https://jsonplaceholder.typicode.com';
}
'@ | Set-Content -Encoding utf8 'lib/src/core/constants/app_constants.dart'

@'
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
'@ | Set-Content -Encoding utf8 'lib/src/core/error/failures.dart'

@'
class ServerException implements Exception {
  ServerException([this.message = 'Server error', this.code]);
  final String message; final int? code;
  @override String toString() => 'ServerException(code: $code, message: $message)';
}
class NetworkException implements Exception {
  NetworkException([this.message = 'No internet connection']);
  final String message; @override String toString() => 'NetworkException(message: $message)';
}
'@ | Set-Content -Encoding utf8 'lib/src/core/error/exceptions.dart'

@'
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo { Future<bool> get isConnected; }
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);
  final Connectivity _connectivity;
  @override Future<bool> get isConnected async => (await _connectivity.checkConnectivity()) != ConnectivityResult.none;
}
'@ | Set-Content -Encoding utf8 'lib/src/core/network/network_info.dart'

@'
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
'@ | Set-Content -Encoding utf8 'lib/src/core/network/dio_client.dart'

@'
import 'package:fpdart/fpdart.dart';
import '../error/failures.dart';

abstract class UseCase<T, P> { Future<Either<Failure, T>> call(P params); }
class NoParams { const NoParams(); }
'@ | Set-Content -Encoding utf8 'lib/src/core/usecase/usecase.dart'

if ($router -eq 'go_router') {
  Write-Step 'Writing router (go_router)'
@'
import 'package:go_router/go_router.dart';
import '../../features/todo/presentation/pages/todo_list_page.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const TodoListPage()),
  ],
);
'@ | Set-Content -Encoding utf8 'lib/src/core/router/app_router.dart'
}

@'
import 'package:flutter/material.dart';

final _lightSeed = const Color(0xFF4F46E5);
final _darkSeed = const Color(0xFF22D3EE);

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
'@ | Set-Content -Encoding utf8 'lib/src/core/theme/app_theme.dart'

Write-Step 'Writing DI'
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/core/di/injection.dart'

Write-Step 'Writing feature: Todo (domain)'
@'
import 'package:equatable/equatable.dart';

class Todo extends Equatable {
  const Todo({required this.id, required this.title, required this.completed});
  final int id; final String title; final bool completed;
  @override List<Object?> get props => [id, title, completed];
}
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/domain/entities/todo.dart'

@'
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/todo.dart';

abstract class TodoRepository { Future<Either<Failure, List<Todo>>> getTodos(); }
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/domain/repositories/todo_repository.dart'

@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/domain/usecases/get_todos.dart'

Write-Step 'Writing feature: Todo (data)'
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/data/models/todo_model.dart'

@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/data/datasources/todo_remote_data_source.dart'

@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/data/repositories/todo_repository_impl.dart'

Write-Step "Writing feature: Todo (presentation) for $state"
switch ($state) {
  'bloc' {
@'
import 'package:equatable/equatable.dart';

enum ViewStatus { idle, loading, success, error }

class TodoListState extends Equatable {
  const TodoListState({this.status = ViewStatus.idle, this.items = const [], this.error});
  final ViewStatus status; final List<dynamic> items; final String? error;
  TodoListState copyWith({ViewStatus? status, List<dynamic>? items, String? error}) =>
      TodoListState(status: status ?? this.status, items: items ?? this.items, error: error);
  @override List<Object?> get props => [status, items, error];
}
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/cubit/todo_list_state.dart'

@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/cubit/todo_list_cubit.dart'

@'
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
            subtitle: Text('ID: ${'$'}{todo.id}'),
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/pages/todo_list_page.dart'
  }
  'riverpod' {
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/providers/todo_list_provider.dart'

@'
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
            subtitle: Text('ID: ${'$'}{todo.id}'),
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/pages/todo_list_page.dart'
  }
  'provider' {
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/notifier/todo_list_notifier.dart'

@'
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
            subtitle: Text('ID: ${'$'}{todo.id}'),
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/pages/todo_list_page.dart'
  }
  'getx' {
@'
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
  void onInit() { super.onInit(); load(); }

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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/controller/todo_controller.dart'

@'
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
            subtitle: Text('ID: ${'$'}{todo.id}'),
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
'@ | Set-Content -Encoding utf8 'lib/src/features/todo/presentation/pages/todo_list_page.dart'
  }
}

Write-Step 'Writing app and main.dart'
if ($router -eq 'go_router') {
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/app.dart'
} else {
  switch ($state) {
    'getx' {
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/app.dart'
    }
    Default {
@'
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
'@ | Set-Content -Encoding utf8 'lib/src/app.dart'
    }
  }
}

switch ($state) {
  'riverpod' {
@'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const ProviderScope(child: App()));
}
'@ | Set-Content -Encoding utf8 'lib/main.dart'
  }
  Default {
@'
import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const App());
}
'@ | Set-Content -Encoding utf8 'lib/main.dart'
  }
}

if (-not $SkipCodegen -and $profile -eq 'full' -and -not $SkipInstall) {
  Write-Step 'Running code generation (json_serializable)'
  & dart run build_runner build --delete-conflicting-outputs | Out-Null
}

if (-not $SkipCodegen) {
  Write-Step 'Formatting Dart files'
  & dart format lib | Out-Null
}

# Replace app name placeholder
($content = Get-Content -Raw 'lib/src/core/constants/app_constants.dart').Replace('APP_NAME_PLACEHOLDER', $name) | Set-Content -Encoding utf8 'lib/src/core/constants/app_constants.dart'

Write-Ok "Clean Architecture scaffolded ($state)."
Write-Host "Run the app: flutter run -d windows (or any device)" -ForegroundColor Magenta
if (-not $router -and -not $auto) {
  Write-Host "Use go_router for navigation?" -ForegroundColor Cyan
  Write-Host "  1) No (Navigator)"
  Write-Host "  2) Yes (go_router)"
  do { $sel = Read-Host '› Enter 1-2' } until ($sel -in '1','2')
  $router = @('none','go_router')[[int]$sel-1]
}

if ($router -and $router -notin 'go_router','none') { throw "Invalid --router: $router" }
