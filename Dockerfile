# Базовый образ
FROM python:3.8-slim

# Создаем директорию для проекта
RUN mkdir /app
WORKDIR /app

# Настройка кэширования pip
RUN mkdir -p ~/.cache/pip && \
    chmod -R 777 ~/.cache/pip

# Установка системных зависимостей
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    libmariadb-dev-compat \
    libmariadb-dev \
    libssl-dev \
    zlib1g-dev \
    gcc

# Копируем необходимые папки
COPY common/ /app/common/
COPY requirements/edx/base.txt /app/
COPY requirements/edx/development.txt /app/

# Обновляем pip и устанавливаем зависимости
RUN pip install --upgrade pip && \
    sed -i 's/py2neo==3.1.2/py2neo==2021.2.4/g' base.txt && \
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
