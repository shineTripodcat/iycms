FROM ubuntu:latest

WORKDIR /app/iycms

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    jq \
    cron \
    sed \
    curl\
    mysql-client\
    && rm -rf /var/lib/apt/lists/*

# 设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' > /etc/timezone

# 安装架构检测工具
RUN apt-get update && apt-get install -y file && rm -rf /var/lib/apt/lists/*
ARG TARGETARCH

# 根据架构下载对应版本
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    wget --no-check-certificate "https://github.com/shineTripodcat/iycms/raw/main/Download/cms-linux_x86-64-v3.3.44.zip" -O iycms.zip \
    && unzip -o -q iycms.zip -d /opt/iycms \
    && rm -f iycms.zip; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    wget --no-check-certificate "https://github.com/shineTripodcat/iycms/raw/main/Download/cms-linux_arm64-v3.3.44.zip" -O iycms.zip \
    && unzip -o -q iycms.zip -d /opt/iycms \
    && rm -f iycms.zip; \
    else \
    echo "Unsupported architecture: $TARGETARCH" && exit 1; \
    fi

# 设置文件权限
RUN chmod +x /opt/iycms/cms

# 复制 update.sh 脚本到 /opt/iycms 目录
COPY update.sh /opt/iycms/update.sh
RUN chmod +x /opt/iycms/update.sh

# 复制压缩包到模板目录
COPY seo004.zip /app/iycms/data/tpl/
# 创建目标目录并解压（自动创建目录需加 -d 参数）
RUN mkdir -p /app/iycms/data/tpl/seo004 \
    && unzip -o -q /app/iycms/data/tpl/seo004.zip -d /app/iycms/data/tpl/seo004/ \
    && chmod -R 755 /app/iycms/data/tpl/seo004



# 创建启动脚本
RUN echo '#!/bin/bash\n' \
    'cp -r /opt/iycms/* /app/iycms/\n' \
    'chmod +x /app/iycms/cms\n' \
    'exec /app/iycms/cms\n' > /start.sh \
    && chmod +x /start.sh

# 添加定时任务配置
RUN echo '0 0 * * * /app/iycms/update.sh' >> /etc/crontab

# 启动 cron 服务
RUN service cron start

# 删除 VOLUME 声明（或明确挂载点）
# VOLUME ["/app/iycms"]

EXPOSE 80
EXPOSE 21007

CMD ["/bin/bash", "/start.sh"]
