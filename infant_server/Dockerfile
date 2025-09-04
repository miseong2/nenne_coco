# Use the official Dart image.
FROM dart:stable

WORKDIR /app

# 1) dart_frog_cli 활성화 + PATH 등록
RUN dart pub global activate dart_frog_cli
ENV PATH="/root/.pub-cache/bin:${PATH}"

# 2) 의존성 캐시
COPY pubspec.* ./
RUN dart pub get

# 3) 소스 복사 & 빌드
COPY . .
RUN dart_frog build

# 4) 생성된 서버 엔트리에서 IPv6 → IPv4로 패치 (핵심!)
RUN sed -i "s/InternetAddress.tryParse('') ?? InternetAddress.anyIPv6/InternetAddress.anyIPv4/" build/bin/server.dart

EXPOSE 8080

# 5) 실행
CMD ["dart", "run", "build/bin/server.dart"]
    