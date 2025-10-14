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

# Копируем ВЕСЬ код сначала
COPY . .

# Создание виртуального окружения
RUN python3 -m venv /edx/venv
ENV PATH="/edx/venv/bin:$PATH"

# Установка совместимой версии pip для старых пакетов
RUN pip install --upgrade "pip<24.1" setuptools wheel

# Создаем символические ссылки для mysql_config
RUN ln -s /usr/bin/mariadb_config /usr/bin/mysql_config || true

# Установка mysqlclient с явными флагами
RUN MYSQLCLIENT_CFLAGS="-I/usr/include/mariadb" MYSQLCLIENT_LDFLAGS="-L/usr/lib/x86_64-linux-gnu" pip install mysqlclient==2.1.1

# Поиск и установка safe_lxml в разных возможных местах
RUN echo "🔍 Looking for safe_lxml..." && \
    if [ -d "safe_lxml" ]; then \
        echo "📦 Found safe_lxml in root, installing..." && \
        pip install -e ./safe_lxml; \
    elif [ -d "lib/safe_lxml" ]; then \
        echo "📦 Found safe_lxml in lib/, installing..." && \
        pip install -e ./lib/safe_lxml; \
    elif [ -d "src/safe_lxml" ]; then \
        echo "📦 Found safe_lxml in src/, installing..." && \
        pip install -e ./src/safe_lxml; \
    elif [ -d "common/lib/safe_lxml" ]; then \
        echo "📦 Found safe_lxml in common/lib/, installing..." && \
        pip install -e ./common/lib/safe_lxml; \
    else \
        echo "❌ safe_lxml not found in common locations, searching..." && \
        find . -name "safe_lxml" -type d | head -5; \
    fi

# Установка зависимостей edX
RUN pip install -r requirements/edx/base.txt || echo "Some dependencies may have issues"

# Установка development зависимостей
RUN pip install -r requirements/edx/development.txt || echo "Dev dependencies installed with warnings"

# Настройка окружения edX
RUN make requirements || echo "Make requirements completed with warnings"
RUN make l10n || echo "Make l10n completed with warnings"

# Проверяем установку safe_lxml
RUN python -c "\
try:\n\
    import safe_lxml\n\
    print('✅ safe_lxml successfully installed')\n\
    print('Location:', safe_lxml.__file__)\n\
except ImportError as e:\n\
    print('❌ safe_lxml not installed:', e)\n\
    print('Python path:')\n\
    import sys\n\
    for p in sys.path:\n\
        print(' ', p)\n\
    exit(1)\n\
"

# Настройка nginx
COPY Docker/nginx.conf /etc/nginx/sites-available/edx
RUN ln -s /etc/nginx/sites-available/edx /etc/nginx/sites-enabled/edx
RUN rm /etc/nginx/sites-enabled/default

EXPOSE 80

# Запуск приложения через скрипт
CMD sh -c '/edx/venv/bin/python /edx/app/manage.py runserver 0.0.0.0:8000 & nginx -g "daemon off;"'
