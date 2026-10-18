# ==========================================
# Stage 1: Build Flutter Web Release
# ==========================================
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Salin konfigurasi dependensi untuk memaksimalkan layer caching Docker
COPY pubspec.yaml pubspec.lock* ./

# Unduh dependensi paket
RUN flutter pub get

# Salin seluruh kode sumber proyek
COPY . .

# Pastikan web support aktif dan build aplikasi ke mode release
RUN flutter build web --release

# ==========================================
# Stage 2: Production Nginx Server
# ==========================================
FROM nginx:alpine

# Salin konfigurasi Nginx khusus untuk Single Page Application (SPA)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Salin aset statis hasil build dari Stage 1 ke webroot Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Port web container
EXPOSE 80

# Jalankan Nginx di foreground
CMD ["nginx", "-g", "daemon off;"]
