FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# ติดตั้ง dependencies พื้นฐาน
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl task-thai locales tzdata \
    protobuf-compiler libprotobuf-dev libprotoc-dev grpc-proto protobuf-compiler-grpc libgrpc++-dev libgrpc-dev && \
    rm -rf /var/lib/apt/lists/*

# ตั้งค่า Locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen th_TH.UTF-8 && \
    update-locale LANG=th_TH.UTF-8 LC_ALL=th_TH.UTF-8

# ตั้งค่า Timezone
RUN ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
    echo "Asia/Bangkok" >> /etc/timezone

ENV LANG=th_TH.UTF-8
ENV LC_ALL=th_TH.UTF-8
ENV TZ=Asia/Bangkok

WORKDIR /app

# คัดลอก project file และ restore dependencies
COPY aspnetcore/rssnews.csproj ./aspnetcore/
COPY protobuf/rss.proto ./protobuf/

RUN dotnet restore aspnetcore/rssnews.csproj

# คัดลอก source code ทั้งหมด
COPY aspnetcore/ ./aspnetcore/

WORKDIR /app/aspnetcore

# Publish application
RUN dotnet publish rssnews.csproj \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false \
    /p:GenerateDocumentationFile=false

# ========== Migration Stage ==========
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS migration

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash curl task-thai locales tzdata gnupg apt-transport-https software-properties-common && \
    rm -rf /var/lib/apt/lists/*

# ติดตั้ง SQL Server tools
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    curl https://packages.microsoft.com/config/debian/12/prod.list | tee /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 \
    mssql-tools18 \
    unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

# เพิ่ม SQL tools ใน PATH
ENV PATH="$PATH:/opt/mssql-tools18/bin"

# ตั้งค่า Locale และ Timezone
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen th_TH.UTF-8

ENV LANG=th_TH.UTF-8
ENV LC_ALL=th_TH.UTF-8
ENV TZ=Asia/Bangkok

WORKDIR /app

# ติดตั้ง EF Core tools
ENV PATH="$PATH:/root/.dotnet/tools"
RUN dotnet tool install --global dotnet-ef --version 9.0.8
COPY aspnetcore/rssnews.csproj ./aspnetcore/
COPY protobuf/rss.proto ./protobuf/
RUN dotnet restore aspnetcore/rssnews.csproj
# คัดลอกไฟล์จาก build stage
COPY --from=build /app/aspnetcore/ ./aspnetcore/
COPY --from=build /app/publish/ ./publish/
COPY database/setup.sql /app/database/setup.sql
COPY aspnetcore/add-migration.sh /usr/local/bin/add-migration.sh
RUN chmod +x /usr/local/bin/add-migration.sh

WORKDIR /app/aspnetcore

# ========== Runtime Stage ==========
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final

# ติดตั้ง dependencies ที่จำเป็น
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl gnupg netcat-openbsd net-tools jq iputils-ping tcpdump traceroute \
    task-thai locales tzdata fonts-noto-core fonts-noto-extra fonts-sipa-arundina fonts-thai-tlwg && \
    rm -rf /var/lib/apt/lists/*

# ติดตั้ง SQL Server tools (สำหรับ health checks)
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    curl https://packages.microsoft.com/config/debian/12/prod.list | tee /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 \
    mssql-tools18 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/opt/mssql-tools18/bin"

# ตั้งค่า Locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "th_TH.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen th_TH.UTF-8

ENV LANG=th_TH.UTF-8
ENV LC_ALL=th_TH.UTF-8
ENV TZ=Asia/Bangkok

RUN ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime && \
    echo "Asia/Bangkok" >> /etc/timezone

# สร้าง user และ group
RUN groupadd -r rssnews && \
    useradd -r -g rssnews -d /var/www/rssnews -s /sbin/nologin rssnews

WORKDIR /var/www/rssnews

# คัดลอกไฟล์ที่ publish แล้ว
COPY --from=build /app/publish ./
COPY aspnetcore/entrypoint.sh /usr/local/bin/entrypoint.sh

# ตั้งค่า permissions
RUN chown -R rssnews:rssnews /var/www/rssnews && \
    chmod +x /usr/local/bin/entrypoint.sh

# สร้าง directory สำหรับ logs
RUN mkdir -p /var/log/rssnews && \
    chown -R rssnews:rssnews /var/log/rssnews

USER rssnews

EXPOSE 5000 5001

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]