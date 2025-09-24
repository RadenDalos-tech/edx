# Базовый образ
FROM python:3.8-slim

# Устанавливаем git для работы с репозиториями
RUN apt-get update && \
    apt-get install -y \
    git \
    build-essential \
    libmariadb-dev-compat \
    libmariadb-dev \
    libssl-dev \
    zlib1g-dev \
    gcc

# Создаем директорию для проекта
RUN mkdir /app
WORKDIR /app

# Настройка кэширования pip
RUN mkdir -p ~/.cache/pip && \
    chmod -R 777 ~/.cache/pip

# Копируем всю структуру проекта
COPY openedx/ /app/openedx/
COPY common/ /app/common/
COPY requirements/edx/base.txt /app/
COPY requirements/edx/development.txt /app/

# Обновляем pip и устанавливаем зависимости
RUN pip install --upgrade pip && \
    sed -i 's/py2neo==3.1.2/py2neo==2021.2.4/g' base.txt && \
    # Исправляем формат git-зависимостей
    sed -i 's/git\+https:\/\/github.com\/edx\/codejail.git@3.1.3#egg=codejail==3.1.3/git+https:\/\/github.com\/edx\/codejail.git@3.1.3/g' base.txt && \
    sed -i 's/git\+https:\/\/github.com\/edx\/django-ratelimit-backend.git@v2.0.1a5#egg=django-ratelimit-backend==2.0.1a5/git+https:\/\/github.com\/edx\/django-ratelimit-backend.git@v2.0.1a5/g' base.txt && \
    sed -i 's/git\+https:\/\/github.com\/edx\/MongoDBProxy.git@d92bafe9888d2940f647a7b2b2383b29c752f35a#egg=MongoDBProxy==0.1.0+edx.2/git+https:\/\/github.com\/edx\/MongoDBProxy.git@d92bafe9888d2940f647a7b2b2383b29c752f35a/g' base.txt && \
    sed -i 's/git\+https:\/\/github.com\/edx-solutions\/xblock-drag-and-drop-v2@v2.2.10#egg=xblock-drag-and-drop-v2==2.2.10/git+https:\/\/github.com\/edx-solutions\/xblock-drag-and-drop-v2@v2.2.10/g' base.txt && \
    sed -i 's/git\+https:\/\/github.com\/open-craft\/xblock-poll@1efd04bd6e16252a20e39a7516f9b69a000ace24#egg=xblock-poll==1.10.0/git+https:\/\/github.com\/open-craft\/xblock-poll@1efd04bd6e16252a20e39a7516f9b69a000ace24/g' base.txt && \
    pip install -r base.txt && \
    pip install -r development.txt

# Копирование остальных файлов проекта
COPY . /app

# Установка прав доступа
RUN chmod -R 755 /app

# Установка окружения edX
RUN make requirements
RUN make l10n

# Опциональная проверка установленных пакетов
# RUN pip list
