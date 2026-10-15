FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /etc/ssl/certs /etc/ssl/certs
COPY --from=build /app/bin/server /app/bin/server

ENV PORT=8080
EXPOSE 8080

CMD ["/app/bin/server"]
