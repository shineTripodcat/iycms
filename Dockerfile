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

# 新增：复制并处理 SEO 模板文件
COPY seo004.zip /opt/iycms/data/tpl/
RUN unzip -o -q /opt/iycms/data/tpl/seo004.zip -d /opt/iycms/data/tpl/ \
    && rm -f /opt/iycms/data/tpl/seo004.zip \
    && chmod -R 755 /opt/iycms/data/tpl

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

VOLUME ["/app/iycms"]

EXPOSE 80
EXPOSE 21007

CMD ["/bin/bash", "/start.sh"]
