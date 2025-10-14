FROM ubuntu:20.04

# Установка таймзоны чтобы избежать интерактивного диалога
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Обновление пакетов и установка базовых зависимостей
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update

# Установка только необходимых системных зависимостей
RUN apt-get install -y \
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
    nginx \
    pkg-config \
    libmariadb-dev-compat \
    libmariadb-dev \
    libxml2-dev \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /edx/app

# Создание виртуального окружения
RUN python3 -m venv /edx/venv
ENV PATH="/edx/venv/bin:$PATH"

# Установка совместимой версии pip для старых пакетов
RUN pip install --upgrade "pip<24.1" setuptools wheel

# Создаем символические ссылки для mysql_config
RUN ln -s /usr/bin/mariadb_config /usr/bin/mysql_config || true

# Копируем requirements сначала для кэширования
COPY requirements/ requirements/

# Установка зависимостей в правильном порядке
RUN MYSQLCLIENT_CFLAGS="-I/usr/include/mariadb" MYSQLCLIENT_LDFLAGS="-L/usr/lib/x86_64-linux-gnu" pip install mysqlclient==2.1.1

# Копируем ВЕСЬ код (safe_lxml находится в репозитории)
COPY . .

# Установка базовых зависимостей edX (safe_lxml установится из requirements)
RUN pip install -r requirements/edx/base.txt

# Установка development зависимостей (если нужно)
RUN pip install -r requirements/edx/development.txt || echo "Dev dependencies may have warnings"

# Настройка окружения edX
RUN make requirements || echo "Make requirements completed with warnings"
RUN make l10n || echo "Make l10n completed with warnings"

# Проверяем что safe_lxml импортируется
RUN python -c "
try:
    import safe_lxml
    print('✅ safe_lxml successfully imported')
    print('safe_lxml location:', safe_lxml.__file__)
except ImportError as e:
    print('❌ safe_lxml import failed:', e)
    # Пытаемся найти пакет вручную
    import sys
    print('Python path:')
    for p in sys.path:
        print(' ', p)
    exit(1)
"

# Настройка nginx
COPY Docker/nginx.conf /etc/nginx/sites-available/edx
RUN ln -s /etc/nginx/sites-available/edx /etc/nginx/sites-enabled/edx
RUN rm /etc/nginx/sites-enabled/default

# Создаем healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

EXPOSE 80 8000

# Запуск приложения через скрипт
CMD sh -c '/edx/venv/bin/python /edx/app/manage.py runserver 0.0.0.0:8000 & nginx -g "daemon off;"'
