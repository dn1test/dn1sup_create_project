# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/projects_store.rb — реестр проектов и работа с YAML-
# карточкой проекта.
#
# Индекс (projects.yaml в AppData) хранит только зарегистрированные пути —
# источник истины о проекте лежит в его собственной YAML-карточке
# (карточка + project_history, два документа, формат старого create_project.rb,
# расширенный полями description и files). Поэтому зарегистрировать можно
# и чужую папку — карточка будет создана при первом открытии.
# =============================================================================

require 'yaml'
require 'fileutils'

module Dn1supCreateProject
  module ProjectsStore
    extend self

    INDEX_NAME = 'projects.yaml'

    # -- индекс ----------------------------------------------------------------

    def index_path(data_dir: nil)
      File.join(data_dir || Settings.dir, INDEX_NAME)
    end

    def load_index(data_dir: nil)
      file = index_path(data_dir: data_dir)
      return [] unless File.exist?(file)

      data = YAML.safe_load(File.read(file, encoding: 'UTF-8')) || {}
      Array(data['projects'])
    rescue StandardError
      []
    end

    def save_index(entries, data_dir: nil)
      file = index_path(data_dir: data_dir)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, YAML.dump('projects' => entries), encoding: 'UTF-8')
      entries
    end

    # Нормализация пути для сравнения: прямые слеши, вниз регистром (Windows).
    def normalize(path)
      File.expand_path(path.to_s).tr('\\', '/').downcase
    end

    # Регистрирует проект (папку). Возвращает обновлённый индекс.
    # unknown: true — папка, ещё не имеющая карточки.
    def register(project_path, data_dir: nil)
      expanded = File.expand_path(project_path).tr('\\', '/')
      key = normalize(expanded)
      entries = load_index(data_dir: data_dir)
      exists = entries.any? { |e| normalize(e.is_a?(String) ? e : e['path']) == key }
      unless exists
        entries << {
          'path' => expanded,
          'registered_at' => Time.now.strftime('%Y-%m-%d %H:%M'),
          'unknown' => card_path(expanded).nil?
        }
        save_index(entries, data_dir: data_dir)
      end
      entries
    end

    def unregister(project_path, data_dir: nil)
      key = normalize(project_path)
      entries = load_index(data_dir: data_dir).reject { |e| normalize(e.is_a?(String) ? e : e['path']) == key }
      save_index(entries, data_dir: data_dir)
      entries
    end

    # Список проектов для UI: индекс + краткие данные карточки.
    def list(data_dir: nil)
      load_index(data_dir: data_dir).map do |entry|
        path = entry.is_a?(String) ? entry : entry['path']
        found = read_card(path)
        card = found && found[0]
        {
          'path' => path,
          'registered_at' => entry.is_a?(String) ? nil : entry['registered_at'],
          'unknown' => card.nil?,
          'name' => card ? card['project_name'] : File.basename(path),
          'articul' => card ? card['articul'] : '',
          'type' => card ? card['project_type'] : '',
          'place' => card ? card['place'] : '',
          'product' => card ? card['product'] : '',
          'description' => card ? card['description'].to_s : '',
          'files_count' => card && card['files'] ? card['files'].size : 0
        }
      end
    end

    # -- карточка проекта -------------------------------------------------------

    # Список реальных подпапок внутри проекта для UI
    def list_subfolders(project_path)
      return [] if project_path.nil? || !File.directory?(project_path)

      Dir.children(project_path).select do |entry|
        full = File.join(project_path, entry)
        File.directory?(full) && !entry.start_with?('.')
      end.sort
    rescue StandardError
      []
    end

    # Ищет YAML-карточку в корне проекта: первый *.{yaml,yml}, чей первый документ
    # содержит ключ 'articul' (карточка) либо это наш пустой шаблон.
    def card_path(project_path)
      return nil if project_path.nil? || !File.directory?(project_path)

      candidates = Dir.glob(File.join(project_path, '*.{yaml,yml}')).sort
      candidates.each do |file|
        docs = safe_load_stream(file)
        next if docs.empty?

        first = docs.first
        return file if first.is_a?(Hash) && (first.key?('articul') || first.key?('project_name'))
      end
      nil
    end

    # Читает карточку и историю. Возвращает [card, history] или nil.
    def read_card(project_path)
      file = card_path(project_path)
      return nil unless file

      docs = safe_load_stream(file)
      card = docs.first.is_a?(Hash) ? docs.first : {}
      history = docs[1].is_a?(Hash) ? docs[1] : { 'project_history' => [] }
      card['files'] ||= []
      card['description'] ||= ''
      card['subfolders'] = list_subfolders(project_path)
      card['path'] = project_path.to_s.tr('\\', '/')
      [card, history]
    end

    # Открывает проект: при отсутствии карточки создаёт минимальную
    # (для зарегистрированных «чужих» папок). Возвращает [card, history].
    def open(project_path)
      found = read_card(project_path)
      return found if found

      name = File.basename(File.expand_path(project_path))
      card = {
        'project_name' => name,
        'project_type' => '',
        'articul' => '',
        'customer_name' => '',
        'company_name' => '',
        'address' => '',
        'place' => name,
        'product' => '',
        'description' => '',
        'files' => []
      }
      history = { 'project_history' => [
        { 'data' => Time.now.strftime('%Y-%m-%d %H:%M'),
          'status' => 'Регистрация', 'version' => 1, 'revision' => 1,
          'text' => 'Проект зарегистрирован вручную' }
      ] }
      write_card(project_path, card, history)
      card['path'] = project_path.to_s.tr('\\', '/')
      [card, history]
    end

    # Перезаписывает карточку + историю (два YAML-документа, как в старом формате).
    def write_card(project_path, card, history)
      stored = card.reject { |k, _| k == 'path' }
      file = card_path(project_path) || default_card_file(project_path, stored)
      File.write(file, YAML.dump_stream(stored, history), encoding: 'UTF-8')
      file
    end

    # Добавляет запись истории и сохраняет карточку.
    def append_history(project_path, card, history, status, text)
      entries = history['project_history'] ||= []
      last = entries.last || {}
      entries << {
        'data' => Time.now.strftime('%Y-%m-%d %H:%M'),
        'status' => status,
        'version' => (last['version'] || 1),
        'revision' => (last['revision'] || 1) + 1,
        'text' => text
      }
      write_card(project_path, card, history)
    end

    private

    def safe_load_stream(file)
      YAML.load_stream(File.read(file, encoding: 'UTF-8'))
    rescue StandardError
      []
    end

    def default_card_file(project_path, card)
      base = card['articul'].to_s
      base = File.basename(File.expand_path(project_path)) if base.strip.empty?
      File.join(project_path, "#{Generator.sanitize_filename(base)}.yaml")
    end
  end
end
