# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/generator.rb — генерация структуры мебельных проектов.
# Санитизация имён, шаблоны папок «заказ → проект», имена файлов, копирование
# шаблонов .skp/.pur и добавленных файлов, YAML-карточка проекта
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

    # -- имена -----------------------------------------------------------------------

    # Удаляет символы <>, заменяет запрещённые в Windows на _.
    def sanitize_filename(name)
      result = name.to_s.dup
      result.gsub!(/[<>]/, '')
      result.gsub!(/["|?*:\/\\]/, '_')
      result
    end

    # Заполняет шаблон вида '{place} ~ {product}' значениями и чистит пустоты:
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

    def template_vars(type, order:, product:)
      {
        customer: order['customer'].to_s,
        company: order['company'].to_s,
        address: order['address'].to_s,
        phone: order['phone'].to_s,
        email: order['email'].to_s,
        place: order['place'].to_s,
        product: product_value(type, product)
      }
    end

    # -- создание структуры ------------------------------------------------------------

    # Корневая папка заказа (1-й уровень): base_path + шаблон order для типа.
    def order_root(settings, type, base_path, order)
      tpl = settings.dig('structure', 'folders', type, 'order') ||
            (type == 'commercial' ? '{customer} ~ {company} ~ {address}' : '{customer} ~ {address}')
      vars = template_vars(type, order: order, product: '')
      File.join(base_path, sanitize_filename(fill_template(tpl, vars)))
    end

    # Создаёт один проект на диске. Возвращает хеш со string-ключами (для моста):
    # path, skp, pur, yaml, card.
    # Структура: base_path/папка заказа (1-й уровень)/папка проекта (2-й уровень).
    def create_project(settings, plug_root:, base_path:, type:, order:, project:)
      # место установки и продукт живут в проекте, не в заказе
      full_order = order.merge('place' => project['place'].to_s)
      product = project['product'].to_s
      vars = template_vars(type, order: full_order, product: product)

      project_tpl = settings.dig('structure', 'folders', type, 'project') ||
                    (type == 'commercial' ? '{place} ~ {product}' : '{place}')
      root = order_root(settings, type, base_path, order)
      project_path = unique_path(File.join(root, sanitize_filename(fill_template(project_tpl, vars))))
      FileUtils.mkdir_p(project_path)

      skp_name, pur_name = build_file_names(settings, vars)
      yaml_name = "#{sanitize_filename(fill_template(settings.dig('naming', 'yaml_file') || '{place}', vars))}.yaml"

      copy_template(settings, plug_root, 'skp', File.join(project_path, skp_name))
      copy_template(settings, plug_root, 'pur', File.join(project_path, pur_name))

      card = build_card(settings, type: type, order: full_order, project: project, product: product)
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

    # Имена файлов внутри проекта: {place} ~ {product}.skp и {place}.pur.
    def build_file_names(settings, vars)
      skp_base = sanitize_filename(fill_template(settings.dig('naming', 'skp_file') || '{place} ~ {product}', vars))
      pur_base = sanitize_filename(fill_template(settings.dig('naming', 'pur_file') || '{place}', vars))
      ["#{skp_base}.skp", "#{pur_base}.pur"]
    end

    def build_card(_settings, type:, order:, project:, product:)
      {
        'project_name' => project_name(type, order: order, product: product),
        'project_type' => type == 'commercial' ? 'Коммерческая' : 'Бытовая',
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

    # Если папка с таким именем уже есть (тот же место+продукт) — добавляем
    # счётчик: «Кухня (2)», «Кухня (3)»…
    def unique_path(path)
      return path unless File.exist?(path)

      index = 2
      loop do
        suffixed = "#{path} (#{index})"
        return suffixed unless File.exist?(suffixed)

        index += 1
      end
    end
  end
end
