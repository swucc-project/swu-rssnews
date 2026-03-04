# ========== Build Stage ==========
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release

# ติดตั้ง dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl task-thai locales tzdata \
    protobuf-compiler libprotobuf-dev libprotoc-dev \
    grpc-proto protobuf-compiler-grpc \
    libgrpc++-dev libgrpc-dev && \
    rm -rf /var/lib/apt/lists/*

# ตั้งค่า Locale และ Timezone
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen th_TH.UTF-8

RUN ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime

ENV LANG=th_TH.UTF-8 \
    LC_ALL=th_TH.UTF-8 \
    TZ=Asia/Bangkok

WORKDIR /app

# ✅ สร้าง directories ที่จำเป็น
RUN mkdir -p /app/protobuf /app/aspnetcore

# ✅ คัดลอก protobuf files ก่อน
COPY protobuf/rss.proto ./protobuf/rss.proto

# คัดลอก project file
COPY aspnetcore/rssnews.csproj ./aspnetcore/

WORKDIR /app/aspnetcore

# Restore packages (รวม Grpc.Tools)
RUN dotnet restore "rssnews.csproj" --verbosity detailed

COPY aspnetcore/ ./

RUN dotnet build "rssnews.csproj" -c $BUILD_CONFIGURATION -o /app/build --no-restore

RUN cp -r /app/aspnetcore/obj /app/aspnetcore-obj

# Publish
RUN dotnet publish rssnews.csproj -c Release -o /app/publish --no-restore

# ========== Migration Stage ========== 
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS migration
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash curl task-thai locales tzdata \
    gnupg apt-transport-https software-properties-common dos2unix \
    protobuf-compiler libprotobuf-dev libprotoc-dev grpc-proto \
    protobuf-compiler-grpc libgrpc-dev libgrpc++-dev && \
    rm -rf /var/lib/apt/lists/*

# ✅ Fix locale BEFORE installing anything else
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=th_TH.UTF-8

# ติดตั้ง SQL Server tools
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    curl https://packages.microsoft.com/config/debian/12/prod.list | tee /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

# ✅ Set TERM to prevent "TERM not set" warning from dotnet-ef
ENV TERM=xterm-256color
ENV PATH="/opt/mssql-tools18/bin:/root/.dotnet/tools:${PATH}"

# Install tools
RUN dotnet tool install --global dotnet-ef --version 9.0.8

# ✅ Use en_US as primary (th_TH causes "cannot change locale" on some kernels)
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    TZ=Asia/Bangkok

WORKDIR /app
RUN mkdir -p /app/aspnetcore /app/protobuf

COPY protobuf/rss.proto ./protobuf/rss.proto
COPY aspnetcore/rssnews.csproj ./aspnetcore/

WORKDIR /app/aspnetcore

RUN dotnet restore "rssnews.csproj" --verbosity detailed

COPY aspnetcore/ ./

COPY --from=build /app/aspnetcore-obj ./obj
RUN dotnet build "rssnews.csproj" --no-restore -c Release
RUN mkdir -p /app/aspnetcore/Migrations

COPY aspnetcore/add-migration.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/add-migration.sh && \
    dos2unix /usr/local/bin/add-migration.sh 2>/dev/null || true

COPY database/setup.sql /app/database/setup.sql

ENTRYPOINT ["/usr/local/bin/add-migration.sh"]

# ========== Runtime Stage ==========
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl gnupg netcat-openbsd net-tools jq \
    iputils-ping openssl tcpdump traceroute \
    task-thai locales tzdata \
    fonts-noto-core fonts-noto-extra \
    fonts-sipa-arundina fonts-thai-tlwg dos2unix && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    curl https://packages.microsoft.com/config/debian/12/prod.list | tee /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/opt/mssql-tools18/bin"

RUN locale-gen th_TH.UTF-8
ENV LANG=th_TH.UTF-8 LC_ALL=th_TH.UTF-8 TZ=Asia/Bangkok

RUN ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime

RUN groupadd -r rssnews && \
    useradd -r -g rssnews -d /var/www/rssnews -s /sbin/nologin rssnews
RUN mkdir -p /var/www/rssnews/grpc-generated && \
    chown -R rssnews:rssnews /var/www/rssnews/grpc-generated
WORKDIR /var/www/rssnews

RUN mkdir -p /var/www/rssnews/apollo && \
    chown -R rssnews:rssnews /var/www/rssnews/apollo

COPY --from=build /app/publish ./

RUN mkdir -p /var/www/rssnews/.aspnet/DataProtection-Keys && \
    chmod 755 /var/www/rssnews/.aspnet/DataProtection-Keys

ENV DOTNET_RUNNING_IN_CONTAINER=true

COPY aspnetcore/kestrel-improvement.sh /usr/local/bin/
COPY aspnetcore/entrypoint.sh /usr/local/bin/

RUN dos2unix /usr/local/bin/*.sh && \
    chown -R rssnews:rssnews /var/www/rssnews && \
    chmod +x /usr/local/bin/*.sh

RUN mkdir -p /var/log/rssnews && \
    chown -R rssnews:rssnews /var/log/rssnews

USER rssnews

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]