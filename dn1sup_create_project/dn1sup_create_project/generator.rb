# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/generator.rb — генерация структуры мебельных проектов.
# Артикулы (префикс + метка времени, фиксируется в момент добавления проекта
# в интерфейсе), санитизация имён, шаблоны папок «заказ → проект», имена файлов,
# копирование шаблонов .skp/.pur и добавленных файлов, YAML-карточка проекта
# с историей (два YAML-документа — формат совместим со старым).
#
# Все имена и списки берутся из настроек (Settings), поэтому структуру можно
# менять в UI «Настройки» или правкой settings.yaml.
# =============================================================================

require 'fileutils'
require 'yaml'

module Dn1supCreateProject
  module Generator
    extend self

    # -- артикулы ------------------------------------------------------------------

    # Форматирует метку времени по шаблону из настроек (по умолчанию %y%m%d_%H%M%S).
    def capture_timestamp(settings, now = Time.now)
      now.strftime(settings.dig('articul', 'timestamp_format') || '%y%m%d_%H%M%S')
    end

    # Артикул проекта: префикс + метка времени (CF#260906_143025 / HF#…).
    # Метка каждого проекта фиксируется в интерфейсе в момент добавления проекта
    # (project_times) и передаётся сюда через time:.
    def build_articul(settings, type, timestamp)
      key = type == 'commercial' ? 'commercial_prefix' : 'household_prefix'
      prefix = settings.dig('articul', key) || 'XX#'
      "#{prefix}#{timestamp}"
    end

    # Метки времени пачки проектов. Артикул фиксируется при добавлении проекта
    # в интерфейсе, поэтому метка приходит готовой — project['time_sec']
    # (epoch-секунды). Проекты без метки получают base + index секунд.
    # Совпавшие секунды (два проекта в одну секунду) сдвигаются на +1 с,
    # чтобы артикулы не повторились.
    def project_times(projects, base: Time.now)
      used = {}
      projects.each_with_index.map do |project, index|
        sec = project['time_sec'].to_i
        time = sec.positive? ? Time.at(sec) : Time.at(base.to_i + index)
        time = Time.at(time.to_i + 1) while used.key?(time.to_i)
        used[time.to_i] = true
        time
      end
    end

    # -- имена -----------------------------------------------------------------------

    # Удаляет символы <>, заменяет запрещённые в Windows на _.
    def sanitize_filename(name)
      result = name.to_s.dup
      result.gsub!(/[<>]/, '')
      result.gsub!(/["|?*:\/\\]/, '_')
      result
    end

    # Заполняет шаблон вида '{articul} ~ {place}' значениями и чистит пустоты:
    # пропущенные сегменты '~' и пустые части после запятой исчезают.
    def fill_template(template, vars)
      filled = template.to_s.gsub(/\{(\w+)\}/) { vars[Regexp.last_match(1).to_sym].to_s }
      segments = filled.split('~').map { |s| compact_commas(s) }.reject { |s| s.strip.empty? }
      segments.join(' ~ ')
    end

    def compact_commas(text)
      text.split(',').map(&:strip).reject(&:empty?).join(', ')
    end

    def product_value(_type, product)
      product.to_s.strip
    end

    def project_name(type, order:, product:)
      if type == 'commercial'
        "#{order['company']}, #{product_value(type, product)} | #{order['place']}, #{order['address']}"
      else
        "#{product_value(type, product)}, #{order['place']} | #{order['customer']}, #{order['address']}"
      end
    end

    def template_vars(type, order:, articul:, product:, timestamp: nil)
      {
        articul: articul,
        customer: order['customer'].to_s,
        company: order['company'].to_s,
        address: order['address'].to_s,
        phone: order['phone'].to_s,
        email: order['email'].to_s,
        place: order['place'].to_s,
        product: product_value(type, product),
        timestamp: timestamp.to_s
      }
    end

    # -- создание структуры ------------------------------------------------------------

    # Корневая папка заказа (1-й уровень): base_path + шаблон order для типа.
    def order_root(settings, type, base_path, order)
      tpl = settings.dig('structure', 'folders', type, 'order') ||
            (type == 'commercial' ? '{customer} ~ {company} ~ {address}' : '{customer} ~ {address}')
      vars = template_vars(type, order: order, articul: '', product: '')
      File.join(base_path, sanitize_filename(fill_template(tpl, vars)))
    end

    # Создаёт один проект на диске. Возвращает хеш со string-ключами (для моста):
    # path, skp, pur, yaml, card.
    # time — метка проекта (Time), зафиксированная при добавлении проекта в UI.
    # Структура: base_path/папка заказа (1-й уровень)/папка проекта (2-й уровень).
    def create_project(settings, plug_root:, base_path:, type:, order:, project:, time: Time.now)
      timestamp = capture_timestamp(settings, time)
      articul = build_articul(settings, type, timestamp)
      # место установки и продукт живут в проекте, не в заказе
      full_order = order.merge('place' => project['place'].to_s)
      product = project['product'].to_s
      vars = template_vars(type, order: full_order, articul: articul, product: product, timestamp: timestamp)

      project_tpl = settings.dig('structure', 'folders', type, 'project') ||
                    (type == 'commercial' ? '{place} ~ {product}' : '{place}')
      root = order_root(settings, type, base_path, order)
      project_path = unique_path(File.join(root, sanitize_filename(fill_template(project_tpl, vars))), articul)
      FileUtils.mkdir_p(project_path)

      skp_name, pur_name = build_file_names(settings, vars)
      yaml_name = "#{sanitize_filename(fill_template(settings.dig('naming', 'yaml_file') || '{articul}', vars))}.yaml"

      copy_template(settings, plug_root, 'skp', File.join(project_path, skp_name))
      copy_template(settings, plug_root, 'pur', File.join(project_path, pur_name))

      card = build_card(settings, type: type, order: full_order, project: project, product: product, articul: articul)
      card['files'] = copy_file_groups(settings, project_path, project['file_groups'])

      File.write(File.join(project_path, yaml_name), YAML.dump_stream(card, initial_history), encoding: 'UTF-8')

      {
        'path' => project_path.tr('\\', '/'),
        'skp' => skp_name,
        'pur' => pur_name,
        'yaml' => yaml_name,
        'card' => card
      }
    end

    # Имена файлов внутри проекта: {place} ~ {product}.skp и {articul}.pur.
    def build_file_names(settings, vars)
      skp_base = sanitize_filename(fill_template(settings.dig('naming', 'skp_file') || '{place} ~ {product}', vars))
      pur_base = sanitize_filename(fill_template(settings.dig('naming', 'pur_file') || '{articul}', vars))
      ["#{skp_base}.skp", "#{pur_base}.pur"]
    end

    def build_card(_settings, type:, order:, project:, product:, articul:)
      {
        'project_name' => project_name(type, order: order, product: product),
        'project_type' => type == 'commercial' ? 'Коммерческая' : 'Бытовая',
        'articul' => articul,
        'customer_name' => order['customer'].to_s,
        'company_name' => order['company'].to_s,
        'phone' => order['phone'].to_s,
        'email' => order['email'].to_s,
        'address' => order['address'].to_s,
        'place' => order['place'].to_s,
        'product' => product_value(type, product),
        'description' => project['description'].to_s,
        'files' => []
      }
    end

    def initial_history
      {
        'project_history' => [
          {
            'data' => Time.now.strftime('%Y-%m-%d %H:%M'),
            'status' => 'В разработке',
            'version' => 1,
            'revision' => 1,
            'text' => 'Предварительный эскиз проекта'
          }
        ]
      }
    end

    # -- файловые группы («Добавить файлы» с именем папки) -----------------------------

    # Копирует группы файлов {folder, paths[]} в папку проекта:
    # каждая группа — своя подпапка внутри проекта. Возвращает записи для карточки.
    def copy_file_groups(settings, project_path, groups)
      entries = []
      Array(groups).each do |group|
        folder = sanitize_filename(group['folder'].to_s)
        folder = '_файлы' if folder.strip.empty?
        entries.concat(ProjectFiles.copy_batch(settings, project_path, folder, Array(group['paths'])))
      end
      entries
    end

    # -- шаблоны -----------------------------------------------------------------------

    # Путь к файлу шаблона: относительный путь — от корня расширения,
    # абсолютный — как есть.
    def template_path(settings, plug_root, key)
      rel = settings.dig('structure', 'templates', key) || "data/template.#{key}"
      expanded = File.expand_path(rel)
      return expanded if rel == expanded || File.absolute_path?(rel)

      File.join(plug_root, rel)
    end

    def copy_template(settings, plug_root, key, destination)
      src = template_path(settings, plug_root, key)
      if File.exist?(src)
        FileUtils.cp(src, destination)
      else
        # Отсутствующий шаблон не останавливает создание — пустой файл-заглушка.
        File.write(destination, '')
      end
    rescue Errno::EACCES, Errno::EBUSY
      puts "[CreateProject] Шаблон занят, пропущен: #{src}"
    end

    private

    # Если папка с таким именем уже есть (тот же место+продукт) — добавляем артикул.
    def unique_path(path, articul)
      return path unless File.exist?(path)

      suffixed = "#{path} (#{sanitize_filename(articul)})"
      File.exist?(suffixed) ? "#{path} #{Time.now.to_i}" : suffixed
    end
  end
end
