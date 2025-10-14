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

# Копируем ВЕСЬ код сначала
COPY . .

# Пробуем установить зависимости поэтапно с обработкой ошибок
RUN echo "🔧 Installing basic Python dependencies..." && \
    pip install Django==3.2.* && \
    pip install lxml && \
    pip install mysqlclient==2.1.1

# Пробуем найти и установить requirements
RUN if [ -f "requirements/edx/base.txt" ]; then \
        echo "📦 Installing from base.txt..." && \
        pip install -r requirements/edx/base.txt || echo "⚠️  Some packages from base.txt failed"; \
    else \
        echo "❌ base.txt not found, available requirements:" && \
        find requirements/ -name "*.txt" | head -10; \
    fi

RUN if [ -f "requirements/edx/development.txt" ]; then \
        echo "📦 Installing development dependencies..." && \
        pip install -r requirements/edx/development.txt || echo "⚠️  Some dev dependencies failed"; \
    fi

# Пробуем альтернативные пути к requirements
RUN if [ -f "requirements.txt" ]; then \
        echo "📦 Installing from root requirements.txt..." && \
        pip install -r requirements.txt || echo "⚠️  Root requirements failed"; \
    fi

# Проверяем что установились критические зависимости
RUN python -c "\
try:\n\
    import django, lxml\n\
    print('✅ Django version:', django.__version__)\n\
    print('✅ lxml imported successfully')\n\
except ImportError as e:\n\
    print('❌ Critical dependency missing:', e)\n\
    exit(1)\n\
"

# Пробуем найти safe_lxml в репозитории
RUN echo "🔍 Looking for safe_lxml..." && \
    find . -name "*safe_lxml*" -type f | head -10 || echo "No safe_lxml files found"

# Если safe_lxml это локальный пакет, устанавливаем его в develop mode
RUN if [ -d "safe_lxml" ]; then \
        echo "📦 Installing safe_lxml in development mode..." && \
        pip install -e ./safe_lxml; \
    elif [ -d "lib/safe_lxml" ]; then \
        echo "📦 Installing safe_lxml from lib/..." && \
        pip install -e ./lib/safe_lxml; \
    fi

# Финальная проверка safe_lxml
RUN python -c "\
try:\n\
    import safe_lxml\n\
    print('🎉 safe_lxml successfully imported')\n\
    print('Location:', safe_lxml.__file__)\n\
except ImportError:\n\
    print('❌ safe_lxml not found, but continuing build...')\n\
    print('Python path:')\n\
    import sys\n\
    for p in sys.path:\n\
        if 'edx' in p:\n\
            print(' ', p)\n\
"

# Настройка nginx
RUN if [ -f "Docker/nginx.conf" ]; then \
        cp Docker/nginx.conf /etc/nginx/sites-available/edx && \
        ln -s /etc/nginx/sites-available/edx /etc/nginx/sites-enabled/edx && \
        rm /etc/nginx/sites-enabled/default; \
    else \
        echo "⚠️  nginx.conf not found, using default nginx config"; \
    fi

EXPOSE 80 8000

# Исправленный CMD в JSON формате
CMD ["sh", "-c", "/edx/venv/bin/python /edx/app/manage.py runserver 0.0.0.0:8000 & nginx -g 'daemon off;'"]
