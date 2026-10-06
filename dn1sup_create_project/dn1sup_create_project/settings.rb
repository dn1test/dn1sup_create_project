# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/settings.rb — настройки структуры проектов (YAML).
#
# Файл хранится в AppData пользователя и переживает обновление/переустановку
# расширения:
#   %APPDATA%/SketchUp/SketchUp <версия>/dn1sup_create_project/settings.yaml
#
# Файл можно править вручную — при чтении недостающие ключи достраиваются из
# DEFAULTS (deep_merge), поэтому частичный YAML безопасен. «Сбросить» в UI
# просто удаляет файл (при следующем чтении создастся из DEFAULTS).
# =============================================================================

require 'yaml'
require 'fileutils'

module Dn1supCreateProject
  module Settings
    extend self

    VERSION = 2

    # -- значения по умолчанию (v2 — структура «заказ → проект» из ТЗ) ------------

    DEFAULTS = {
      'version' => VERSION,
      'defaults' => {
        'projects_root' => '' # корневая папка всех проектов; выбирается в «Настройках»
      },
      'articul' => {
        'commercial_prefix' => 'CF#',
        'household_prefix' => 'HF#',
        # несколько проектов за раз создаются с шагом в 1 секунду —
        # последняя цифра (секунды) артикула отличается
        'timestamp_format' => '%y%m%d_%H%M%S'
      },
      'structure' => {
        # пути к шаблонам: относительные — от корня расширения, абсолютные — как есть
        'templates' => {
          'skp' => 'data/template.skp',
          'pur' => 'data/template.pur'
        },
        # шаблоны папок: order — общий folder 1-го уровня заказа,
        # project — папка каждого проекта (2-й уровень) внутри заказа
        'folders' => {
          'household' => {
            'order' => '{customer} ~ {address}',
            'project' => '{place}'
          },
          'commercial' => {
            'order' => '{customer} ~ {company} ~ {address}',
            'project' => '{place} ~ {product}'
          }
        }
      },
      # имена файлов внутри папки проекта
      # плейсхолдеры: {articul} {customer} {company} {address} {phone} {email} {place} {product} {timestamp}
      'naming' => {
        'skp_file' => '{place} ~ {product}',
        'pur_file' => '{articul}',
        'yaml_file' => '{articul}'
      },
      'lists' => {
        'commercial_products' => ['Торговый остров', 'Стойка ресепшн', 'Торговая мебель', 'Павильон'],
        'places' => %w[Кухня Гостиная Прихожая Спальня Детская Ванная Кабинет Балкон],
        'products_by_place' => {
          'Кухня' => ['Кухонный гарнитур', 'Кухонный остров', 'Буфет', 'Пенал', 'Барная стойка', 'Обеденный стол'],
          'Гостиная' => ['Стенка', 'Тумба-ТВ', 'Шкаф', 'Витрина', 'Комод', 'Полки'],
          'Прихожая' => ['Прихожая', 'Шкаф', 'Шкаф-купе', 'Обувница', 'Тумба', 'Полки'],
          'Спальня' => ['Кровать', 'Шкаф', 'Шкаф-купе', 'Комод', 'Туалетный стол', 'Прикроватная тумба'],
          'Детская' => ['Кровать', 'Шкаф', 'Стол письменный', 'Стеллаж', 'Комод', 'Полки'],
          'Ванная' => ['Тумба под раковину', 'Шкаф-пенал', 'Зеркальный шкаф', 'Полки', 'Стеллаж'],
          'Кабинет' => ['Стол письменный', 'Шкаф', 'Стеллаж', 'Тумба', 'Полки', 'Комод'],
          'Балкон' => ['Шкаф', 'Стеллаж', 'Тумба', 'Полки', 'Рабочий стол']
        },
        # запасной список мебели для нестандартного места
        'other_products' => ['Шкаф', 'Шкаф-купе', 'Стеллаж', 'Комод', 'Тумба', 'Полки']
      },
      'files' => {
        'images' => {
          'folder' => '_изображения',
          'extensions' => %w[jpg jpeg png gif webp bmp tif tiff]
        },
        'documents' => {
          'folder' => '_документы',
          'extensions' => %w[pdf doc docx xls xlsx txt rtf odt dwg]
        }
      }
    }.freeze

    # -- путь к файлу настроек ---------------------------------------------------

    # Каталог данных расширения в AppData (или override через env — для тестов).
    def dir
      @dir ||= begin
        custom = ENV['DN1SUP_CREATE_PROJECT_DATA_DIR']
        if custom && !custom.empty?
          custom.tr('\\', '/')
        else
          File.join(data_root, 'dn1sup_create_project')
        end
      end
    end

    # Каталог пользователя SketchUp: %APPDATA%/SketchUp/SketchUp <год>.
    # Надёжный источник — путь Plugins из самого SketchUp; при недоступности —
    # номер версии: у 2021+ major-версия равна году − 2000 (26.2 → «SketchUp 2026»).
    def data_root
      if defined?(Sketchup) && Sketchup.respond_to?(:find_support_file)
        plugins = Sketchup.find_support_file('Plugins')
        if plugins && !plugins.empty?
          root = File.expand_path('../..', plugins) # Plugins → «SketchUp 2026»
          return root if File.basename(root).start_with?('SketchUp')
        end
      end

      appdata = ENV['APPDATA'] || Dir.home
      major = defined?(Sketchup) && Sketchup.respond_to?(:version) ? Sketchup.version.to_i : 26
      year = major >= 1000 ? major : 2000 + major
      File.join(appdata, 'SketchUp', "SketchUp #{year}")
    end

    def path
      File.join(dir, 'settings.yaml')
    end

    # -- чтение/запись -------------------------------------------------------------

    # Читает настройки, достраивая недостающие ключи из DEFAULTS.
    # data_dir — переопределение каталога (для тестов), кэш @dir не мутирует.
    def load(data_dir: nil)
      d = data_dir || dir
      FileUtils.mkdir_p(d)
      file = File.join(d, 'settings.yaml')
      user = File.exist?(file) ? (YAML.safe_load(File.read(file, encoding: 'UTF-8')) || {}) : {}
      deep_merge(deep_dup(DEFAULTS), user)
    rescue StandardError => e
      puts "[CreateProject] Настройки не прочитаны (#{e.message}) — используются значения по умолчанию"
      deep_dup(DEFAULTS)
    end

    # Сохраняет настройки (хеш целиком) в YAML.
    def save!(settings, data_dir: nil)
      d = data_dir || dir
      FileUtils.mkdir_p(d)
      settings['version'] = VERSION
      File.write(File.join(d, 'settings.yaml'), YAML.dump(settings), encoding: 'UTF-8')
      settings
    end

    # Сброс: удалить файл настроек (при следующем load создастся из DEFAULTS).
    def reset!(data_dir: nil)
      d = data_dir || dir
      file = File.join(d, 'settings.yaml')
      File.delete(file) if File.exist?(file)
      true
    end

    # Обновляет один корневой ключ и сохраняет.
    def update_section!(settings, section, value)
      settings[section] = value
      save!(settings)
    end

    # -- утилиты ---------------------------------------------------------------------

    # Рекурсивное слияние: значения user переопределяют base,
    # отсутствующие в user ключи остаются из base. Хеши сливает, массивы заменяет.
    def deep_merge(base, user)
      result = base || {}
      (user || {}).each do |key, value|
        result[key] = result[key].is_a?(Hash) && value.is_a?(Hash) ? deep_merge(result[key], value) : value
      end
      result
    end

    def deep_dup(obj)
      case obj
      when Hash  then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array then obj.map { |v| deep_dup(v) }
      else obj
      end
    end
  end
end
