#!/usr/bin/env fish
function step; set_color cyan; echo -n "[SETUP] "; set_color normal; echo $argv; end
function ok; set_color green; echo -n "[OK] "; set_color normal; echo $argv; end
function warn; set_color yellow; echo -n "[WARN] "; set_color normal; echo $argv; end

step "Validating environment (Flutter/Dart)"
type -q flutter; or begin; echo "Flutter not found in PATH"; exit 1; end
type -q dart; or begin; echo "Dart not found in PATH"; exit 1; end

test -f pubspec.yaml; or begin; echo "pubspec.yaml not found. Run inside your Flutter project root."; exit 1; end

step "Adding runtime dependencies"
set deps get_it fpdart dio connectivity_plus pretty_dio_logger shared_preferences flutter_secure_storage flutter_bloc equatable json_annotation
for d in $deps
  dart pub add $d
end

step "Adding dev dependencies"
set dev_deps build_runner json_serializable flutter_lints
for d in $dev_deps
  dart pub add -d $d
end

step "Creating folders"
set dirs \
  lib/src/core/constants \
  lib/src/core/di \
  lib/src/core/error \
  lib/src/core/network \
  lib/src/core/usecase \
  lib/src/features/todo/domain/entities \
  lib/src/features/todo/domain/repositories \
  lib/src/features/todo/domain/usecases \
  lib/src/features/todo/data/models \
  lib/src/features/todo/data/datasources \
  lib/src/features/todo/data/repositories \
  lib/src/features/todo/presentation/cubit \
  lib/src/features/todo/presentation/pages
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
  static const appName = 'Clean MVVM App';
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

step "Writing feature: Todo (presentation)"
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
import '../../domain/usecases/get_todos.dart';
import '../cubit/todo_list_cubit.dart';
import '../cubit/todo_list_state.dart';

class TodoListPage extends StatelessWidget {
  const TodoListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TodoListCubit(sl<GetTodos>())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Todos')),
        body: BlocBuilder<TodoListCubit, TodoListState>(
          builder: (context, state) {
            switch (state.status) {
              case ViewStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ViewStatus.error:
                return Center(child: Text(state.error ?? 'Something went wrong'));
              case ViewStatus.success:
                return ListView.separated(
                  itemBuilder: (_, i) {
                    final todo = state.items[i];
                    return ListTile(
                      leading: Icon(
                        (todo.completed as bool) ? Icons.check_circle : Icons.circle_outlined,
                        color: (todo.completed as bool) ? Colors.green : Colors.grey,
                      ),
                      title: Text(todo.title as String),
                      subtitle: Text('ID: ${todo.id}'),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemCount: state.items.length,
                );
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
EOF

step "Writing app and main.dart"
cat > lib/src/app.dart << 'EOF'
import 'package:flutter/material.dart';
import 'features/todo/presentation/pages/todo_list_page.dart';
import 'core/constants/app_constants.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: const TodoListPage(),
    );
  }
}
EOF

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

step "Running code generation"
dart run build_runner build --delete-conflicting-outputs

step "Formatting Dart files"
dart format lib

ok "Clean Architecture (MVVM + BLoC + Dio) scaffolded."
echo "Run: flutter run -d macos | linux | windows"
