## Clean Architecture cho Flutter: Tổng quan + Case Study Pull‑to‑Refresh + Test/Coverage

Tài liệu này giúp hiểu và áp dụng Clean Architecture trong Flutter: nắm nguyên lý, cấu trúc thư mục, triển khai 1 case study cụ thể (Pull‑to‑Refresh danh sách) với Bloc, và thiết lập bộ test/coverage đạt chất lượng cao (≥80% overall, ≥95% domain/usecase).

---

### 1) Clean Architecture trong Flutter

- **Dependency hướng vào trong**: lớp ngoài không được biết chi tiết lớp trong. `presentation` phụ thuộc `domain`, `data` phụ thuộc `domain`; `domain` độc lập thuần Dart.
- **Domain thuần logic nghiệp vụ**: entity, repository contract, use case. Không import Flutter, không HTTP/DIO, không SQflite.
- **Presentation chỉ xử lý UI + state**: Bloc/Cubit/Provider/Riverpod điều phối luồng, không gọi API trực tiếp, luôn thông qua use case.
- **Data triển khai hạ tầng**: repository implementation, datasource (remote/local), mapping DTO ↔ entity, error mapping.

Sơ đồ đơn giản:

```text
presentation → domain ← data
              ↑ rules hướng vào trong
```

---

### 2) Cấu trúc thư mục tham khảo

```text
lib/
  presentation/
    ui/
    controllers/        # Bloc/Cubit/Provider/Riverpod
  domain/
    entities/
    repositories/
    usecases/
  data/
    repositories_impl/
    datasources/
    models/
```

Gợi ý:
- DI có thể dùng GetIt hoặc Riverpod. Controller nhận use case qua constructor (dễ test).
- Luôn tách DTO (data/models) khỏi Entity (domain/entities). Mapping nằm ở data layer.
- Chuẩn hoá lỗi: datasource → repository → use case → presentation chuyển thành thông điệp UX.

---

### 3) Case study: Pull‑to‑Refresh danh sách nhân vật (Bloc)

Mục tiêu: Khi kéo xuống đầu danh sách, app gọi API bỏ qua cache, tải về dữ liệu mới, thay thế toàn bộ list, hiển thị spinner và xử lý lỗi thân thiện.

Acceptance:
- `RefreshIndicator` chỉ kích hoạt khi kéo từ top.
- Luồng refresh gọi `getAllCharacters(forceReload: true)`; kết quả thay thế list hiện tại, reset paging.
- Nếu lỗi, hiển thị snackbar/banner “Refresh failed. Tap to retry.”, không crash.
- Không sửa domain/data contract (ngoại trừ có thể thêm tham số `forceReload` trong use case/repo contract nếu chưa có).

Phạm vi thay đổi: `presentation/controllers/` và `presentation/ui/`. Không chạm `domain/` và `data/` nếu contract đã sẵn sàng.

---

### 4) Triển khai từng bước (Bloc làm ví dụ chính)

4.1 Use Case trong domain (giữ thuần Dart):

```dart
class GetAllCharacters {
  final CharacterRepository repository;
  GetAllCharacters(this.repository);

  Future<List<Character>> call({bool forceReload = false}) {
    return repository.getAll(forceReload: forceReload);
  }
}
```

4.2 Bloc: event/state/handler chính cho refresh:

```dart
sealed class CharacterEvent {}
class RefreshCharacters extends CharacterEvent {}

sealed class CharacterState {}
class CharactersLoading extends CharacterState {}
class CharactersLoaded extends CharacterState {
  final List<Character> items;
  CharactersLoaded(this.items);
}
class CharactersError extends CharacterState {
  final String message;
  CharactersError(this.message);
}

// Trong CharacterBloc
on<RefreshCharacters>((event, emit) async {
  emit(CharactersLoading());
  try {
    final items = await getAllCharacters(forceReload: true);
    emit(CharactersLoaded(items));
  } catch (e) {
    emit(CharactersError('Refresh failed'));
  }
});
```

Lưu ý: `sealed class` yêu cầu Dart 3. Nếu dự án chưa dùng Dart 3, có thể dùng class thường hoặc giải pháp union thay thế.

4.3 UI: bọc danh sách bằng `RefreshIndicator` và đẩy event:

```dart
return RefreshIndicator(
  onRefresh: () async {
    context.read<CharacterBloc>().add(RefreshCharacters());
  },
  child: ListView.builder(
    itemCount: state.items.length,
    itemBuilder: (_, index) => CharacterTile(state.items[index]),
  ),
);
```

4.4 Đảm bảo `onRefresh` chờ hoàn tất (để spinner không tắt sớm)

```dart
// Cần: import 'dart:async';
Future<void> refreshWithAwait(BuildContext context) async {
  final bloc = context.read<CharacterBloc>();
  final completer = Completer<void>();
  late final StreamSubscription sub;
  sub = bloc.stream.listen((state) {
    if (state is CharactersLoaded || state is CharactersError) {
      completer.complete();
      sub.cancel();
    }
  });
  bloc.add(RefreshCharacters());
  await completer.future;
}

return RefreshIndicator(
  onRefresh: () => refreshWithAwait(context),
  child: ListView.builder(/* ... */),
);
```

Gợi ý tương đương:
- Provider/Cubit: gọi lại use case và cập nhật state theo kiểu tương ứng.
- Riverpod: `ref.invalidate(provider)` hoặc trigger notifier để nạp lại dữ liệu.

---

### 5) Chiến lược test & coverage thực chiến (≥80% overall, ≥95% domain)

Ưu tiên test domain vì ổn định và rẻ để bảo trì; presentation và data test ở mức đủ để bảo vệ hành vi quan trọng.

- Domain:
  - Test entity, validator, mapper (thuần Dart, không phụ thuộc framework).
  - Test use case: happy path + error path; mock `CharacterRepository` (mockito/mocktail).
- Data:
  - Test repository implementation: mapping DTO → Entity, và lan truyền lỗi có chủ đích; mock datasource.
  - Test datasource (HTTP): dùng fake client hoặc adapter (ví dụ `http_mock_adapter`/`dio_adapter`).
- Presentation:
  - Bloc/Cubit test (bloc_test): xác minh chuỗi state khi refresh thành công/thất bại.
  - Widget test: `pumpWidget`, `tester.drag` để kích hoạt `RefreshIndicator`, assert spinner và list mới.

Ví dụ Bloc test (rút gọn):

```dart
blocTest<CharacterBloc, CharacterState>(
  'emits loading then loaded on refresh success',
  build: () {
    when(() => getAllCharacters(forceReload: true))
        .thenAnswer((_) async => [Character(id: '1')]);
    return CharacterBloc(getAllCharacters);
  },
  act: (bloc) => bloc.add(RefreshCharacters()),
  expect: () => [isA<CharactersLoading>(), isA<CharactersLoaded>()],
);
```

---

### 6) Lệnh chạy phân tích, test và coverage

Sử dụng Windows PowerShell; mỗi lệnh cách nhau bằng `;` và kết thúc bằng newline.

```powershell
flutter analyze;
flutter test --coverage;
```

Tạo báo cáo HTML (tuỳ chọn, nếu đã cài `lcov`):

```powershell
genhtml coverage/lcov.info -o coverage/html;
```

Lọc file không tính coverage (nếu cần):

```powershell
lcov --remove coverage/lcov.info "**/*.g.dart" "**/generated/**" -o coverage/lcov.info;
```

---

### 7) Gate coverage trên CI (khuyến nghị)

Pipeline cơ bản:
1) `flutter analyze` sạch;
2) `flutter test --coverage` tạo `coverage/lcov.info`;
3) Kiểm tra ngưỡng: ≥80% overall, ≥95% cho thư mục `domain/`.

Ý tưởng gate đơn giản: script đọc `lcov.info`, tính % theo thư mục, fail nếu dưới ngưỡng (Dart/Node đều được).

---

### 8) Checklist nghiệm thu

- UI: `RefreshIndicator` chỉ hoạt động ở top; spinner hiển thị hợp lý.
- Refresh thay thế toàn bộ danh sách và reset paging.
- Lỗi hiển thị snackbar/banner, không crash.
- Không thay đổi contract domain/data (trừ khi thêm `forceReload` hợp lệ).
- `flutter analyze` không warning; test xanh.
- Coverage đạt ≥80% overall và ≥95% domain/usecase.
- Commit message theo Conventional Commits; cập nhật README “Pull‑to‑Refresh: ✅”.

---

### 9) Quản lý mã nguồn

- Nhánh: `feature/add-pull-to-refresh`.
- Commit nhỏ, mỗi commit pass analyze/test. Ví dụ: `feat(ui): add RefreshIndicator`; `feat(bloc): add RefreshCharacters`; `test(widget): add refresh drag test`.

---

### 10) Tài liệu tham khảo

- Ví dụ clean architecture Flutter: `https://github.com/guilherme-v/flutter-clean-architecture-example`.
- Thư viện test: `bloc_test`, `mocktail`/`mockito`.

