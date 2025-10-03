#!/usr/bin/env fish
function step; set_color cyan; echo -n "[SETUP] "; set_color normal; echo $argv; end
function ok; set_color green; echo -n "[OK] "; set_color normal; echo $argv; end
function warn; set_color yellow; echo -n "[WARN] "; set_color normal; echo $argv; end

function banner
  echo "──────────────────────────────────────────────────────────────"
  echo "      Flutter Clean Architecture ▸ Generator (M3)"
  echo "──────────────────────────────────────────────────────────────"
end

set STATE_MGMT ""
set APP_NAME "Clean MVVM App"
set AUTO false
set PROFILE standard
set SKIP_INSTALL false
set SKIP_CODEGEN false
set ROUTER ""

# Parse flags: --state, --name
set idx 1
while test $idx -le (count $argv)
  set flag $argv[$idx]
  switch $flag
    case --state
      set idx (math $idx + 1)
      set STATE_MGMT $argv[$idx]
    case --name
      set idx (math $idx + 1)
      set APP_NAME $argv[$idx]
    case --profile
      set idx (math $idx + 1)
      set PROFILE $argv[$idx]
    case --skip-install
      set SKIP_INSTALL true
    case --skip-codegen
      set SKIP_CODEGEN true
    case --router
      set idx (math $idx + 1)
      set ROUTER $argv[$idx]
    case --auto
      set AUTO true
    case -h --help
      echo "Usage: scripts/setup-fish.fish [--state bloc|riverpod|provider|getx] [--name \"App Name\"]"
      exit 0
    case '*'
      # ignore unknown for now
  end
  set idx (math $idx + 1)
end

banner

if test $AUTO = true
  if test -f pubspec.yaml
    set nm (awk -F: '/^name:/ {print $2; exit}' pubspec.yaml | xargs)
    if test -n "$nm"; set APP_NAME "$nm"; end
    if rg -n "^\s*flutter_riverpod\s*:" pubspec.yaml >/dev/null 2>&1
      set STATE_MGMT riverpod
    else if rg -n "^\s*provider\s*:" pubspec.yaml >/dev/null 2>&1
      set STATE_MGMT provider
    else if rg -n "^\s*get\s*:" pubspec.yaml >/dev/null 2>&1
      set STATE_MGMT getx
    else
      set STATE_MGMT bloc
    end
    if rg -n "^\s*go_router\s*:" pubspec.yaml >/dev/null 2>&1
      set ROUTER go_router
    else
      set ROUTER none
    end
  else
    set STATE_MGMT bloc
    set ROUTER none
  end
end

if test -z "$STATE_MGMT"
  echo "Choose state management:"
  echo "  1) BLoC/Cubit"
  echo "  2) Riverpod"
  echo "  3) Provider"
  echo "  4) GetX"
  read -P "› Enter 1-4: " choice
  switch $choice
    case 1; set STATE_MGMT bloc
    case 2; set STATE_MGMT riverpod
    case 3; set STATE_MGMT provider
    case 4; set STATE_MGMT getx
    case '*'
      echo "Invalid selection"; exit 1
  end
end

switch $STATE_MGMT
  case bloc riverpod provider getx
  case '*'
    echo "Invalid --state: $STATE_MGMT"; exit 1
end

if test -z "$ROUTER"; and test $AUTO = false
  echo "Use go_router for navigation?"
  echo "  1) No (Navigator)"
  echo "  2) Yes (go_router)"
  read -P "› Enter 1-2: " rsel
  switch $rsel
    case 1; set ROUTER none
    case 2; set ROUTER go_router
    case '*'; echo "Please enter 1-2"; exit 1
  end
end

switch $ROUTER
  case none go_router
  case '*'
    set ROUTER none
end

step "Validating environment (Flutter/Dart)"
type -q flutter; or begin; echo "Flutter not found in PATH"; exit 1; end
type -q dart; or begin; echo "Dart not found in PATH"; exit 1; end

test -f pubspec.yaml; or begin; echo "pubspec.yaml not found. Run inside your Flutter project root."; exit 1; end

step "Resolving dependencies profile ($PROFILE) for $STATE_MGMT"
set deps get_it dio equatable
switch $STATE_MGMT
  case bloc; set deps $deps flutter_bloc
  case riverpod; set deps $deps flutter_riverpod
  case provider; set deps $deps provider
  case getx; set deps $deps get
end
if test $PROFILE = minimal
  set deps $deps fpdart
else if test $PROFILE = standard
  set deps $deps connectivity_plus pretty_dio_logger fpdart
else
  set deps $deps connectivity_plus pretty_dio_logger shared_preferences flutter_secure_storage fpdart json_annotation
end
if test $ROUTER = go_router
  set deps $deps go_router
end
if test $SKIP_INSTALL = false
  dart pub add $deps
else
  warn "Skipping dependency installation (--skip-install)"
end

step "Adding dev dependencies"
if test $SKIP_INSTALL = false
  if test $PROFILE = full
    dart pub add -d flutter_lints build_runner json_serializable
  else if test $PROFILE = standard
    dart pub add -d flutter_lints
  else
    warn "Skipping dev dependencies for minimal profile"
  end
end

step "Creating folders"
set dirs \
  lib/src/core/constants \
  lib/src/core/di \
  lib/src/core/error \
  lib/src/core/network \
  lib/src/core/usecase \
  lib/src/core/theme \
  lib/src/features/todo/domain/entities \
  lib/src/features/todo/domain/repositories \
  lib/src/features/todo/domain/usecases \
  lib/src/features/todo/data/models \
  lib/src/features/todo/data/datasources \
  lib/src/features/todo/data/repositories
switch $STATE_MGMT
  case bloc; set dirs $dirs lib/src/features/todo/presentation/cubit lib/src/features/todo/presentation/pages
  case riverpod; set dirs $dirs lib/src/features/todo/presentation/providers lib/src/features/todo/presentation/pages
  case provider; set dirs $dirs lib/src/features/todo/presentation/notifier lib/src/features/todo/presentation/pages
  case getx; set dirs $dirs lib/src/features/todo/presentation/controller lib/src/features/todo/presentation/pages
end
for d in $dirs
  mkdir -p $d
end

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

cat > lib/src/core/usecase/usecase.dart << 'EOF'
import 'package:fpdart/fpdart.dart';
import '../error/failures.dart';

abstract class UseCase<T, P> { Future<Either<Failure, T>> call(P params); }
class NoParams { const NoParams(); }
EOF

cat > lib/src/core/theme/app_theme.dart << 'EOF'
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
EOF

if test $ROUTER = go_router
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
end

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

step "Writing feature: Todo (presentation) for $STATE_MGMT"
switch $STATE_MGMT
  case bloc
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
  case riverpod
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
  case provider
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
  case getx
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
end

step "Writing app and main.dart"
if test $ROUTER = go_router
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
  switch $STATE_MGMT
    case getx
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
    case '*'
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
  end
end

switch $STATE_MGMT
  case riverpod
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
  case '*'
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
end

if test $SKIP_CODEGEN = false; and test $PROFILE = full; and test $SKIP_INSTALL = false
  step "Running code generation"
  dart run build_runner build --delete-conflicting-outputs >/dev/null
end

if test $SKIP_CODEGEN = false
  step "Formatting Dart files"
  dart format lib >/dev/null
end

# Replace app name placeholder safely using fish string replace
set content (cat lib/src/core/constants/app_constants.dart)
set content (string replace -a 'APP_NAME_PLACEHOLDER' "$APP_NAME" -- $content)
printf %s "$content" > lib/src/core/constants/app_constants.dart

ok "Clean Architecture scaffolded ($STATE_MGMT)."
echo "Run: flutter run -d macos | linux | windows"
