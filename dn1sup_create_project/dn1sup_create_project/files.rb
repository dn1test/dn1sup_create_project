# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/files.rb — файлы проекта: добавление изображений и
# документов (копирование в проект), описания к файлам, подпапки.
#
# Файлы копируются в целевые подпапки по категории (image → files.images.folder,
# document → files.documents.folder, остальное → documents). Реестр файлов
# живёт в карточке проекта (files[]) — путь относительно корня проекта.
# =============================================================================

require 'fileutils'

module Dn1supCreateProject
  module ProjectFiles
    extend self

    CATEGORIES = %w[image document other].freeze

    # Категория по расширению (nil — явно передана категория 'other').
    def category_for(settings, filename)
      ext = File.extname(filename.to_s).delete('.').downcase
      return 'image' if Array(settings.dig('files', 'images', 'extensions')).include?(ext)
      return 'document' if Array(settings.dig('files', 'documents', 'extensions')).include?(ext)

      'other'
    end

    def target_folder(settings, category)
      case category
      when 'image' then settings.dig('files', 'images', 'folder') || '_изображения'
      when 'document' then settings.dig('files', 'documents', 'folder') || '_документы'
      else settings.dig('files', 'documents', 'folder') || '_документы'
      end
    end

    # Копирует одну группу файлов в именованную подпапку проекта (без карточки —
    # используется генератором при создании проекта до записи YAML).
    # Возвращает массив записей для card['files'].
    def copy_batch(settings, project_path, folder, paths)
      dest_dir = File.join(project_path, folder)
      FileUtils.mkdir_p(dest_dir)

      Array(paths).filter_map do |src|
        src = src.to_s
        next unless File.file?(src)

        dest = unique_destination(dest_dir, File.basename(src))
        begin
          FileUtils.cp(src, dest)
        rescue StandardError => e
          puts "[CreateProject] Файл не скопирован (#{e.message}): #{src}"
          next
        end
        {
          'path' => rel_path(project_path, dest),
          'category' => category_for(settings, src),
          'description' => '',
          'added_at' => Time.now.strftime('%Y-%m-%d %H:%M')
        }
      end
    end

    # Копирует файлы в проект и регистрирует их в карточке.
    # paths — массив исходных путей; category — nil (авто) или 'image'/'document'/'other';
    # descriptions — { исходное_имя_файла => описание } (необязательно).
    # Возвращает { added:, skipped: [...] } (string-ключи для моста).
    def add_files(settings, project_path, paths, category: nil, descriptions: {})
      card, history = ProjectsStore.open(project_path)
      added = []
      skipped = []

      Array(paths).each do |src|
        src = src.to_s
        unless File.file?(src)
          skipped << { 'source' => src, 'reason' => 'файл не найден' }
          next
        end

        cat = category || category_for(settings, src)
        dest_dir = File.join(project_path, Generator.sanitize_filename(target_folder(settings, cat)))
        FileUtils.mkdir_p(dest_dir)

        dest = unique_destination(dest_dir, File.basename(src))
        begin
          FileUtils.cp(src, dest)
        rescue StandardError => e
          skipped << { 'source' => src, 'reason' => e.message }
          next
        end

        rel = rel_path(project_path, dest)
        entry = {
          'path' => rel,
          'category' => cat,
          'description' => descriptions[File.basename(src)].to_s,
          'added_at' => Time.now.strftime('%Y-%m-%d %H:%M')
        }
        card['files'] ||= []
        card['files'] << entry
        added << entry
      end

      unless added.empty?
        ProjectsStore.append_history(project_path, card, history, 'Файлы',
                                     "Добавлено файлов: #{added.size} (#{added.map { |f| File.basename(f['path']) }.join(', ')})")
      end

      { 'added' => added, 'skipped' => skipped }
    end

    # Убирает файл из карточки; delete_from_disk — удалить и с диска.
    def remove_file(settings, project_path, rel_path, delete_from_disk: false)
      card, history = ProjectsStore.open(project_path)
      entry = Array(card['files']).find { |f| f['path'] == rel_path }
      return false unless entry

      card['files'] = Array(card['files']).reject { |f| f['path'] == rel_path }
      if delete_from_disk
        full = File.join(project_path, rel_path)
        File.delete(full) if File.file?(full)
      end
      ProjectsStore.append_history(project_path, card, history, 'Файлы',
                                   "Убран файл: #{File.basename(rel_path)}#{delete_from_disk ? ' (удалён с диска)' : ''}")
      true
    end

    # Обновляет описание конкретного файла в карточке.
    def set_file_description(project_path, rel_path, description)
      card, history = ProjectsStore.open(project_path)
      entry = Array(card['files']).find { |f| f['path'] == rel_path }
      return false unless entry

      entry['description'] = description.to_s
      ProjectsStore.write_card(project_path, card, history)
      true
    end

    # Сохраняет описание проекта в карточке + запись в историю.
    def set_description(project_path, description)
      card, history = ProjectsStore.open(project_path)
      old = card['description'].to_s
      return false if old == description.to_s

      card['description'] = description.to_s
      ProjectsStore.append_history(project_path, card, history, 'Описание',
                                   old.empty? ? 'Добавлено описание проекта' : 'Изменено описание проекта')
      true
    end

    # Создаёт подпапку внутри проекта (имя санитизируется).
    def create_subfolder(project_path, name)
      safe = Generator.sanitize_filename(name.to_s)
      return nil if safe.strip.empty?

      full = File.join(project_path, safe)
      FileUtils.mkdir_p(full)
      full.tr('\\', '/')
    end

    private

    # Путь файла относительно корня проекта, с прямыми слэшами.
    def rel_path(project_path, full_path)
      full_path[project_path.to_s.length..-1].to_s.sub(%r{\A[/\\]}, '').tr('\\', '/')
    end

    # Не перезаписываем существующие: "фото.jpg" → "фото (1).jpg".
    def unique_destination(dir, filename)
      ext = File.extname(filename)
      base = File.basename(filename, ext)
      candidate = File.join(dir, filename)
      counter = 0
      while File.exist?(candidate)
        counter += 1
        candidate = File.join(dir, "#{base} (#{counter})#{ext}")
      end
      candidate
    end
  end
end
