FROM python:3.8-slim

# Установка системных зависимостей
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    libmysqlclient-dev \
    default-libmysqlclient-dev \
    libssl-dev \
    zlib1g-dev \
    gcc

# Установка pip зависимостей
COPY requirements/edx/base.txt /app/
COPY requirements/edx/development.txt /app/

WORKDIR /app

RUN pip install --upgrade pip && \
    pip install -r base.txt && \
    pip install -r development.txt

# Копирование файлов проекта
COPY . /app

# Установка прав доступа
RUN chmod -R 755 /app

# Установка окружения edX
RUN make requirements
RUN make l10n
