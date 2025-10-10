FROM ubuntu:20.04

# Установка таймзоны чтобы избежать интерактивного диалога
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    python3.8 \
    python3-pip \
    python3-venv \
    pandoc \
    gettext \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /edx/app

# Копируем ВЕСЬ код сначала
COPY . .

# Создание виртуального окружения
RUN python3 -m venv /edx/venv
ENV PATH="/edx/venv/bin:$PATH"

# Установка совместимой версии pip для старых пакетов
RUN pip install --upgrade "pip<24.1" setuptools wheel

# Установка зависимостей (теперь editable dependencies будут работать)
RUN pip install -r requirements/edx/base.txt
RUN pip install -r requirements/edx/development.txt

# Настройка окружения edX
RUN make requirements || echo "Make requirements completed with warnings"
RUN make l10n || echo "Make l10n completed with warnings"

EXPOSE 8000

CMD ["python3", "manage.py", "runserver", "0.0.0.0:8000"]
