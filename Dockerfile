# Базовый образ
FROM python:3.8-slim

# Обновление pip
RUN python -m pip install --upgrade pip

# Установка системных зависимостей
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    libmysqlclient-dev \
    default-libmysqlclient-dev \
    libssl-dev \
    zlib1g-dev \
    gcc

# Копируем requirements
COPY requirements/edx/base.txt /app/
COPY requirements/edx/development.txt /app/

WORKDIR /app

# Обновляем pip и устанавливаем зависимости
RUN pip install --upgrade pip && \
    # Заменяем py2neo на совместимую версию
    sed -i 's/py2neo==3.1.2/py2neo==2021.2.4/g' base.txt && \
    pip install -r base.txt && \
    pip install -r development.txt

# Копирование файлов проекта
COPY . /app

# Установка прав доступа
RUN chmod -R 755 /app

# Установка окружения edX
RUN make requirements
RUN make l10n

