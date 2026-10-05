# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/generator.rb — генерация структуры мебельных проектов.
# Портировано из старого CLI create_project.rb: артикулы, санитизация имён,
# шаблоны имён папок/файлов, копирование шаблонов .skp/.pur, YAML-карточка
# проекта с историей (два YAML-документа — формат совместим со старым).
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

    # Фиксирует временную метку один раз на сессию создания (YYMMDDHHMMSS).
    def capture_timestamp(settings, now = Time.now)
      now.strftime(settings.dig('articul', 'timestamp_format') || '%y%m%d%H%M%S')
    end

    # Артикул проекта: CF#<ts> для коммерческого, HF#<ts>NN для бытового.
    def build_articul(settings, type, counter, timestamp)
      key = type == 'commercial' ? 'commercial_prefix' : 'household_prefix'
      prefix = settings.dig('articul', key) || 'XX#'
      return "#{prefix}#{timestamp}" if type == 'commercial'

      "#{prefix}#{timestamp}#{counter.to_s.rjust(2, '0')}"
    end

    # Перенумерация бытовых артикулов после добавления/удаления проекта.
    def renumber_articuls(settings, type, projects, timestamp)
      return projects if type == 'commercial'

      projects.each_with_index do |project, index|
        project['articul'] = build_articul(settings, type, index + 1, timestamp)
      end
      projects
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

    # Продукт для карточки: первый для коммерческих/одиночного, список через запятую.
    def product_value(type, products)
      list = Array(products).reject { |p| p.to_s.strip.empty? }
      return '' if list.empty?
      return list.first if type == 'commercial' || list.length == 1

      list.join(', ')
    end

    def project_name(type, order:, products:)
      if type == 'commercial'
        "#{order['company']}, #{product_value(type, products)} | #{order['place']}, #{order['address']}"
      else
        "#{product_value(type, products)}, #{order['place']} | #{order['customer']}, #{order['address']}"
      end
    end

    def template_vars(type, order:, articul:, products:, timestamp: nil)
      {
        articul: articul,
        customer: order['customer'].to_s,
        company: order['company'].to_s,
        address: order['address'].to_s,
        place: order['place'].to_s,
        product: product_value(type, products),
        timestamp: timestamp.to_s
      }
    end

    # -- создание структуры ------------------------------------------------------------

    # Создаёт один проект на диске. Возвращает хеш со string-ключами (для моста):
    # path, skp, pur, yaml, card.
    def create_project(settings, plug_root:, base_path:, type:, order:, project:, counter:, timestamp:)
      articul = build_articul(settings, type, counter, timestamp)
      # место установки живёт в проекте, не в заказе (у бытового заказа несколько мест)
      full_order = order.merge('place' => project['place'].to_s)
      vars = template_vars(type, order: full_order, articul: articul, products: project['products'], timestamp: timestamp)

      folder_name = type == 'commercial' ? settings.dig('naming', 'commercial_folder') : settings.dig('naming', 'household_project_folder')
      project_path = File.join(base_path, sanitize_filename(fill_template(folder_name, vars)))
      FileUtils.mkdir_p(project_path)

      skp_name, pur_name = build_file_names(settings, type, vars)
      yaml_name = "#{sanitize_filename(fill_template(settings.dig('naming', 'yaml_file') || '{articul}', vars))}.yaml"

      copy_template(settings, plug_root, 'skp', File.join(project_path, skp_name))
      copy_template(settings, plug_root, 'pur', File.join(project_path, pur_name))

      card = build_card(settings, type: type, order: full_order, project: project, articul: articul)
      File.write(File.join(project_path, yaml_name), YAML.dump_stream(card, initial_history), encoding: 'UTF-8')

      create_subfolders(settings, project_path)

      {
        'path' => project_path.tr('\\', '/'),
        'skp' => skp_name,
        'pur' => pur_name,
        'yaml' => yaml_name,
        'card' => card
      }
    end

    def build_file_names(settings, type, vars)
      if type == 'commercial'
        base = sanitize_filename(fill_template(settings.dig('naming', 'commercial_file') || '', vars))
        ["#{base}.skp", "#{base}.pur"]
      else
        skp_base = sanitize_filename(fill_template(settings.dig('naming', 'household_skp_file') || '', vars))
        pur_base = sanitize_filename(fill_template(settings.dig('naming', 'pur_file') || '{articul}', vars))
        ["#{skp_base}.skp", "#{pur_base}.pur"]
      end
    end

    def build_card(settings, type:, order:, project:, articul:)
      {
        'project_name' => project_name(type, order: order, products: project['products']),
        'project_type' => type == 'commercial' ? 'Коммерческая' : 'Бытовая',
        'articul' => articul,
        'customer_name' => order['customer'].to_s,
        'company_name' => order['company'].to_s,
        'address' => order['address'].to_s,
        'place' => order['place'].to_s,
        'product' => product_value(type, project['products']),
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

    # Путь к файлу шаблона (относительный путь — от корня расширения).
    def template_path(settings, plug_root, key)
      rel = settings.dig('structure', 'templates', key) || "data/template.#{key}"
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

    def create_subfolders(settings, project_path)
      Array(settings.dig('structure', 'subfolders')).each do |sub|
        FileUtils.mkdir_p(File.join(project_path, sanitize_filename(sub)))
      end
    end
  end
end
