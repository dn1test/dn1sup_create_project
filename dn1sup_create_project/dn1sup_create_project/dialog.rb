# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/dialog.rb — окно «Создать проект» (UI::HtmlDialog).
# Стиль GUI — Vue 3 + Tailwind CSS (Vite singlefile bundle), тёмная/светлая тема.
# Разметка и логика: ui/index.html (собран из frontend/).
#
# Обмен Ruby ↔ JS: один экшен-колбэк 'call_ruby' (name + JSON-параметр) и
# пуш-функции window.pushState / window.pushResult. Файлы выбираются
# нативными диалогами Windows (UI.openpanel / UI.select_directory) на стороне
# Ruby: <input type="file"> в CEF не отдаёт полные пути.
# =============================================================================

require 'json'
require 'fileutils'

module Dn1supCreateProject
  module DialogWindow
    extend self

    begin
      require 'fiddle/import'

      module WinAPI
        extend Fiddle::Importer
        dlload 'user32.dll'
        extern 'void* FindWindowW(const void*, const void*)'
        extern 'int IsIconic(void*)'
        extern 'int ShowWindow(void*, int)'
        extern 'int SetForegroundWindow(void*)'
      end

      SUPPORTED = true
    rescue LoadError, StandardError
      SUPPORTED = false
    end

    SW_RESTORE = 9

    def raise_from_taskbar
      return unless SUPPORTED

      title = (Dn1supCreateProject.window_title + "\0").encode('UTF-16LE')
      hwnd = WinAPI.FindWindowW(nil, title)
      return if hwnd.nil? || (hwnd.respond_to?(:null?) && hwnd.null?)
      return if WinAPI.IsIconic(hwnd).zero?

      WinAPI.ShowWindow(hwnd, SW_RESTORE)
      WinAPI.SetForegroundWindow(hwnd)
    rescue StandardError
      nil
    end
  end

  class << self
    def window_title
      "Create Project v#{VERSION} — проекты"
    end

    def show_dialog
      dlg = @dialog
      if dlg && dlg.visible?
        dlg.bring_to_front
        DialogWindow.raise_from_taskbar
        return dlg
      end
      # Закрытый HtmlDialog повторным show не поднимается — пересоздаём.
      dialogs.delete(dlg) if dlg
      # Ширина жёстко фиксирована (min_width == max_width), регулируется только высота.
      dlg = track_dialog(UI::HtmlDialog.new(
                           dialog_title: window_title,
                           preferences_key: 'dn1sup_create_project_dialog',
                           width: 780, height: 520,
                           min_width: 780, max_width: 780,
                           min_height: 520,
                           resizable: true,
                           use_file_input: true,
                           style: UI::HtmlDialog::STYLE_DIALOG
                         ))
      dlg.set_file(File.join(PLUG_ROOT, 'ui', 'index.html'))
      register_callbacks(dlg)
      dlg.show
      @dialog = dlg
    end

    # -- колбэки -----------------------------------------------------------------

    def register_callbacks(dlg)
      dlg.add_action_callback('call_ruby') do |_ctx, name, param|
        dispatch(dlg, name.to_s, param.to_s)
      end
    end

    def dispatch(dlg, name, param)
      case name
      when 'ready', 'get_state'
        push_state(dlg)
      when 'pick_folder'
        pick_folder(dlg, param)
      when 'pick_file'
        pick_files(dlg, param)
      when 'pick_files'
        pick_files(dlg, param)
      when 'pick_folder_files'
        pick_folder_files(dlg, param)
      when 'pick_template'
        pick_template(dlg, param)
      when 'register_existing'
        register_existing(dlg)
      when 'unregister_project'
        safe { ProjectsStore.unregister(param) }
        push_state(dlg)
      when 'create_projects'
        create_projects(dlg, param)
      when 'add_template'
        add_template(dlg, param)
      when 'get_project'
        send_project(dlg, param)
      when 'save_description'
        change = parse_json(param)
        safe { ProjectFiles.set_description(change['path'], change['description']) }
        send_project(dlg, change['path'])
        push_state(dlg)
      when 'add_files'
        add_files(dlg, param)
      when 'remove_file'
        change = parse_json(param)
        safe { ProjectFiles.remove_file(Settings.load, change['path'], change['rel_path'], delete_from_disk: change['delete_from_disk']) }
        send_project(dlg, change['path'])
        push_state(dlg)
      when 'set_file_description'
        change = parse_json(param)
        safe { ProjectFiles.set_file_description(change['path'], change['rel_path'], change['description']) }
        send_project(dlg, change['path'])
      when 'create_subfolder'
        change = parse_json(param)
        created = safe { ProjectFiles.create_subfolder(change['path'], change['name']) }
        push_result(dlg, 'subfolder_created', 'path' => created, 'name' => change['name'])
        send_project(dlg, change['path'])
      when 'open_folder'
        safe { WinShell.open_folder(param) }
      when 'open_file'
        safe { WinShell.open_file(param) }
      when 'reveal'
        safe { WinShell.reveal(param) }
      when 'save_settings'
        save_settings(dlg, param)
      when 'reset_settings'
        safe { Settings.reset! }
        push_state(dlg)
      when 'open_settings_file'
        safe { WinShell.reveal(Settings.path) }
      when 'update_from_dev'
        safe do
          if defined?(UI) && UI.respond_to?(:start_timer)
            UI.start_timer(0.05, false) do
              res = DevUpdater.update_and_reload!(reopen_dialog: true, notify: false)
              if !res['success'] && defined?(UI)
                UI.messagebox("Ошибка обновления из dev-папки:\n#{res['error']}")
              end
            end
          else
            DevUpdater.update_and_reload!(reopen_dialog: true, notify: false)
          end
        end
      end
    end

    # -- действия ---------------------------------------------------------------

    def pick_folder(dlg, purpose)
      default = Settings.load.dig('defaults', 'projects_root').to_s
      default = Dir.home if default.empty?
      path = UI.select_directory(title: 'Выберите папку', directory: default)
      push_result(dlg, 'pick_folder', 'purpose' => purpose, 'path' => path.to_s)
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    FILE_PICK_FILTER = 'Изображения|*.jpg;*.jpeg;*.png;*.gif;*.webp;*.bmp;*.tif;*.tiff|' \
                       'Документы|*.pdf;*.doc;*.docx;*.xls;*.xlsx;*.txt;*.rtf;*.odt|' \
                       'Все файлы|*.*'.freeze

    # param: purpose — выбор нескольких файлов нативным диалогом Windows
    # (UI.openpanel умеет только один файл, поэтому WinShell.pick_files_multi).
    def pick_files(dlg, purpose)
      paths = WinShell.pick_files_multi('Выберите файлы', FILE_PICK_FILTER)
      push_result(dlg, 'pick_files', 'purpose' => purpose.to_s, 'paths' => paths, 'folder_name' => '')
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    # param: purpose — выбор папки; возвращает все её файлы (группа файлов проекта).
    def pick_folder_files(dlg, purpose)
      dir = UI.select_directory(title: 'Выберите папку с файлами', directory: Dir.home)
      if dir.nil? || dir.to_s.empty?
        return push_result(dlg, 'pick_folder_files', 'purpose' => purpose.to_s, 'paths' => [], 'folder_name' => '')
      end

      paths = Dir.children(dir)
                  .map { |name| File.join(dir, name) }
                  .select { |p| File.file?(p) && !File.basename(p).start_with?('.', '~$') }
                  .sort
      push_result(dlg, 'pick_folder_files', 'purpose' => purpose.to_s, 'paths' => paths,
                  'folder_name' => File.basename(dir))
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    # param: 'skp'|'pur' — выбор файла шаблона нативным диалогом + добавление.
    def pick_template(dlg, param)
      kind = param.to_s
      unless %w[skp pur].include?(kind)
        return push_result(dlg, 'error', 'message' => 'Неизвестный тип шаблона')
      end

      filter = kind == 'skp' ? 'Файлы SketchUp|*.skp|Все файлы|*.*||' : 'Файлы Pro100|*.pur|Все файлы|*.*||'
      src = UI.openpanel("Выберите шаблон .#{kind}", Dir.home, filter)
      if src.nil? || src.to_s.empty?
        return push_result(dlg, 'template_cancelled', 'kind' => kind)
      end

      result = safe do
        dest_dir = File.join(PLUG_ROOT, 'data')
        FileUtils.mkdir_p(dest_dir)
        dest = File.join(dest_dir, "template.#{kind}")
        FileUtils.cp(src, dest)
        # Шаблон в data/ — сбрасываем возможный абсолютный путь в настройках.
        settings = Settings.load
        settings['structure']['templates'][kind] = "data/template.#{kind}"
        Settings.save!(settings)
        dest.tr('\\', '/')
      end
      push_result(dlg, 'template_added', 'kind' => kind, 'path' => result.to_s)
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    def register_existing(dlg)
      default = Settings.load.dig('defaults', 'projects_root').to_s
      default = Dir.home if default.empty?
      path = UI.select_directory(title: 'Выберите папку проекта', directory: default)
      return if path.nil? || path.empty?

      safe { ProjectsStore.register(path) }
      push_state(dlg)
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    # param: {type, base_path?, order:{customer, company, phone, email, address},
    #         projects:[{place, product, file_groups:[{folder, paths[]}]}]}
    # base_path необязателен — иначе берётся defaults.projects_root из настроек.
    def create_projects(dlg, param)
      payload = parse_json(param)
      type = payload['type'] == 'commercial' ? 'commercial' : 'household'
      order = payload['order'] || {}
      projects = Array(payload['projects'])

      base_path = payload['base_path'].to_s
      base_path = Settings.load.dig('defaults', 'projects_root').to_s if base_path.empty?
      if base_path.empty?
        return push_result(dlg, 'error', 'message' => 'Укажите директорию проектов в Настройках')
      end
      unless File.directory?(base_path)
        begin
          require 'fileutils'
          FileUtils.mkdir_p(base_path)
        rescue SystemCallError => e
          return push_result(dlg, 'error', 'message' => "Не удалось создать папку #{base_path}: #{e.message}")
        end
      end
      if projects.empty?
        return push_result(dlg, 'error', 'message' => 'Добавьте хотя бы один проект')
      end
      if type == 'commercial' && order['company'].to_s.strip.empty?
        return push_result(dlg, 'error', 'message' => 'Укажите название фирмы для коммерческого проекта')
      end

      results = safe do
        settings = Settings.load

        # Папку заказа (1-й уровень) для обоих типов строит Generator.create_project.
        created = projects.map do |project|
          Generator.create_project(settings,
                                   plug_root: PLUG_ROOT,
                                   base_path: base_path,
                                   type: type,
                                   order: order,
                                   project: project)
        end
        created.each { |res| ProjectsStore.register(res['path']) }
        remember_root(base_path)
        created
      end

      push_result(dlg, 'created', 'results' => results)
      push_state(dlg)
    end

    # param: {kind: 'skp'|'pur', path} — копирует выбранный файл шаблона в data/.
    def add_template(dlg, param)
      payload = parse_json(param)
      kind = payload['kind'].to_s
      unless %w[skp pur].include?(kind)
        return push_result(dlg, 'error', 'message' => 'Неизвестный тип шаблона')
      end

      src = payload['path'].to_s
      unless File.file?(src)
        return push_result(dlg, 'error', 'message' => "Файл не найден: #{src}")
      end

      result = safe do
        dest_dir = File.join(PLUG_ROOT, 'data')
        FileUtils.mkdir_p(dest_dir)
        dest = File.join(dest_dir, "template.#{kind}")
        FileUtils.cp(src, dest)
        # Шаблон в data/ — сбрасываем возможный абсолютный путь в настройках.
        settings = Settings.load
        settings['structure']['templates'][kind] = "data/template.#{kind}"
        Settings.save!(settings)
        dest.tr('\\', '/')
      end
      push_result(dlg, 'template_added', 'kind' => kind, 'path' => result.to_s)
    end

    def add_files(dlg, param)
      payload = parse_json(param)
      settings = Settings.load
      result = safe do
        ProjectFiles.add_files(settings,
                               payload['path'],
                               Array(payload['paths']),
                               category: payload['category'].nil? || payload['category'].to_s.empty? ? nil : payload['category'],
                               descriptions: payload['descriptions'] || {})
      end
      push_result(dlg, 'add_files', result || {})
      send_project(dlg, payload['path'])
      push_state(dlg)
    end

    def save_settings(dlg, param)
      settings = parse_json(param)
      return push_result(dlg, 'error', 'message' => 'Некорректные настройки') unless settings.is_a?(Hash)

      safe { Settings.save!(settings) }
      push_state(dlg)
      push_result(dlg, 'settings_saved', 'path' => Settings.path)
    end

    # -- пуш в диалог ------------------------------------------------------------

    def push_state(dlg)
      payload = safe do
        {
          'version' => VERSION,
          'settings' => Settings.load,
          'projects' => ProjectsStore.list,
          'settings_path' => Settings.path
        }
      end
      dlg.execute_script("window.pushState(#{JSON.generate(payload)});")
    rescue StandardError => e
      puts "[CreateProject] Не удалось передать состояние в диалог: #{e.message}"
    end

    def send_project(dlg, project_path)
      data = safe { ProjectsStore.open(project_path) }
      return if data.nil?

      card, history = data
      dlg.execute_script("window.pushResult('project', #{JSON.generate('card' => card, 'history' => history)});")
    rescue StandardError => e
      puts "[CreateProject] Не удалось передать проект в диалог: #{e.message}"
    end

    def push_result(dlg, kind, payload)
      dlg.execute_script("window.pushResult('#{kind}', #{JSON.generate(payload || {})});")
    rescue StandardError => e
      puts "[CreateProject] Не удалось передать результат в диалог: #{e.message}"
    end

    # -- вспомогательное ------------------------------------------------------------

    def parse_json(text)
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      {}
    end

    # Запоминает корневую папку проектов как значение по умолчанию.
    def remember_root(path)
      settings = Settings.load
      return if path.to_s.empty? || settings.dig('defaults', 'projects_root') == path

      settings['defaults']['projects_root'] = path.to_s
      Settings.save!(settings)
    end
  end
end
