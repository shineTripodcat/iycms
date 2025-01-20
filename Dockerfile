FROM ubuntu:latest

WORKDIR /app/iycms

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    jq \
    cron \
    && rm -rf /var/lib/apt/lists/*
# 设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' > /etc/timezone

# 下载并解压 iycms 到 /opt/iycms
RUN wget --no-check-certificate "https://www.iycms.com/api/v1/download/cms/latest?os=1&kind=x86_64" -O iycms.zip \
    && unzip -o -q iycms.zip -d /opt/iycms \
    && rm -f iycms.zip \
    && chmod +x /opt/iycms/cms

# 复制 update.sh 脚本到 /opt/iycms 目录
COPY update.sh /opt/iycms/update.sh
# 设置 update.sh 为可执行
RUN chmod +x /opt/iycms/update.sh


# 将 /opt/iycms 内容复制到 /app/iycms 并启动 iycms
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
