# Flutter 프로젝트 구조 가이드 (클린 아키텍처)

lib/
├── core/                          # 핵심 기능
│   ├── constants/
│   │   ├── api_constants.dart
│   │   ├── app_colors.dart
│   │   └── app_strings.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   └── api_endpoints.dart
│   └── utils/
│       ├── date_utils.dart
│       └── validators.dart
│
├── data/                          # 데이터 레이어
│   ├── models/
│   │   ├── user/
│   │   │   └── user_model.dart
│   │   └── health/
│   │       ├── weight_record_model.dart
│   │       ├── blood_sugar_model.dart
│   │       └── blood_pressure_model.dart
│   │
│   ├── repositories/              # API 호출 로직
│   │   ├── auth_repository.dart
│   │   ├── weight_repository.dart
│   │   ├── blood_sugar_repository.dart
│   │   └── blood_pressure_repository.dart
│   │
│   └── services/                  # 외부 서비스
│       ├── auth_service.dart
│       └── storage_service.dart   # SharedPreferences
│
├── domain/                        # 비즈니스 로직 (미래)
│   └── usecases/
│       ├── get_user_usecase.dart
│       └── save_weight_usecase.dart
│
├── presentation/                  # UI 레이어
│   ├── shared/                    # 공통 UI
│   │   ├── widgets/
│   │   │   ├── mobile_layout_wrapper.dart
│   │   │   ├── custom_button.dart
│   │   │   └── loading_indicator.dart
│   │   └── styles/
│   │       ├── text_styles.dart
│   │       └── decorations.dart
│   │
│   ├── auth/                      # 인증 화면
│   │   ├── screens/
│   │   │   └── login_screen.dart
│   │   └── widgets/
│   │       └── login_form.dart
│   │
│   ├── home/                      # 홈 화면
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── banner_slider.dart
│   │       ├── popular_products.dart
│   │       └── stats_section.dart
│   │
│   ├── health/                    # 건강 관리
│   │   ├── dashboard/
│   │   │   ├── screens/
│   │   │   │   └── health_dashboard_screen.dart
│   │   │   └── widgets/
│   │   │       ├── health_metric_card.dart
│   │   │       └── date_navigation.dart
│   │   │
│   │   ├── weight/                # 체중 관리
│   │   │   ├── screens/
│   │   │   │   ├── weight_list_screen.dart
│   │   │   │   └── weight_input_screen.dart
│   │   │   └── widgets/
│   │   │       ├── weight_summary_card.dart
│   │   │       └── bmi_card.dart
│   │   │
│   │   ├── blood_sugar/           # 혈당 관리
│   │   │   ├── screens/
│   │   │   └── widgets/
│   │   │
│   │   └── blood_pressure/        # 혈압 관리
│   │       ├── screens/
│   │       └── widgets/
│   │
│   └── shopping/                  # 쇼핑몰
│       ├── screens/
│       │   ├── hybrid_shopping_screen.dart
│       │   └── webview_screen.dart
│       └── widgets/
│
└── main.dart
```

---

## 📁 **각 폴더의 역할**

### **1. core/** - 핵심 기능
```dart
// 앱 전체에서 사용하는 공통 기능
- constants: 상수 (색상, 문자열, API URL 등)
- network: API 통신 관련
- utils: 유틸리티 함수
```

### **2. data/** - 데이터 레이어
```dart
// 데이터 관련 모든 것
- models: 데이터 모델 (JSON ↔ Dart 객체)
- repositories: API 호출 + 에러 처리
- services: 외부 서비스 (인증, 저장소 등)
```

### **3. presentation/** - UI 레이어
```dart
// 화면 관련 모든 것
- shared: 모든 화면에서 쓰는 공통 위젯
- {feature}/screens: 해당 기능의 화면
- {feature}/widgets: 해당 화면에서만 쓰는 위젯
```

---


## 📋 **네이밍 컨벤션**

### **파일명**
```
snake_case.dart

✅ weight_list_screen.dart
✅ blood_sugar_repository.dart
❌ WeightListScreen.dart
❌ BloodSugarRepository.dart
```

### **클래스명**
```
PascalCase

✅ WeightListScreen
✅ BloodSugarRepository
❌ weight_list_screen
❌ bloodSugarRepository
```

### **변수/함수명**
```
camelCase

✅ getUserData()
✅ currentWeight
❌ GetUserData()
❌ current_weight
```
