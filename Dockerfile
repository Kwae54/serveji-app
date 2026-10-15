# =========================================================
# Stage 1: Build Flutter Web
# =========================================================
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.6

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

# Install Flutter version ที่ต้องการโดยตรง
RUN git clone \
    --depth 1 \
    --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git \
    ${FLUTTER_HOME}

# เตรียมเฉพาะ Web
RUN flutter config --enable-web \
    && flutter precache --web \
    && flutter --version

WORKDIR /app

# แยก copy dependency เพื่อใช้ Docker cache ได้
COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get

COPY . .

ARG API_BASE_URL=http://localhost:8080/api/v1
ARG SERVER_BASE_URL=http://localhost:8080
ARG CUSTOMER_WEB_URL=http://localhost:3000

RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=SERVER_BASE_URL=${SERVER_BASE_URL} \
    --dart-define=CUSTOMER_WEB_URL=${CUSTOMER_WEB_URL}


# =========================================================
# Stage 2: Nginx
# =========================================================
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]