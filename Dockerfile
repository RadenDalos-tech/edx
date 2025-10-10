FROM ubuntu:20.04

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    python3.8 \
    python3-pip \
    pandoc \
    gettext \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копирование требований и установка зависимостей
COPY requirements/ ./requirements/
RUN pip3 install -r requirements/edx/base.txt
RUN pip3 install -r requirements/edx/development.txt

# Копирование исходного кода
COPY . .

# Настройка окружения
RUN make requirements
RUN make l10n

EXPOSE 8000

CMD ["python3", "manage.py", "runserver", "0.0.0.0:8000"]
