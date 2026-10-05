# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/dialog.rb — окно «Создать проект» (UI::HtmlDialog).
# Стиль GUI — Vue 3 + Tailwind CSS (Vite singlefile bundle), тёмная/светлая тема.
# Разметка и логика: ui/index.html (собран из frontend/).
#
# Обмен Ruby ↔ JS: один экшен-колбэк 'call_ruby' (name + JSON-параметр) и
# пуш-функции window.pushState / window.pushResult. Опция use_file_input
# возвращает из <input type="file"> полные локальные пути.
# =============================================================================

require 'json'

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
      dlg = track_dialog(UI::HtmlDialog.new(
                           dialog_title: window_title,
                           preferences_key: 'dn1sup_create_project_dialog',
                           width: 1020, height: 700,
                           min_width: 780, min_height: 520,
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
      when 'register_existing'
        register_existing(dlg)
      when 'unregister_project'
        safe { ProjectsStore.unregister(param) }
        push_state(dlg)
      when 'create_projects'
        create_projects(dlg, param)
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
      when 'create_subfolder'
        change = parse_json(param)
        created = safe { ProjectFiles.create_subfolder(change['path'], change['name']) }
        push_result(dlg, 'subfolder_created', 'path' => created)
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
      path = UI.select_directory('Выберите папку', default)
      push_result(dlg, 'pick_folder', 'purpose' => purpose, 'path' => path.to_s)
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    def register_existing(dlg)
      default = Settings.load.dig('defaults', 'projects_root').to_s
      default = Dir.home if default.empty?
      path = UI.select_directory('Выберите папку проекта', default)
      return if path.nil? || path.empty?

      safe { ProjectsStore.register(path) }
      push_state(dlg)
    rescue StandardError => e
      push_result(dlg, 'error', 'message' => e.message)
    end

    # param: {type, base_path, order:{customer,address,company}, projects:[{place, products:[]}]}
    def create_projects(dlg, param)
      payload = parse_json(param)
      type = payload['type'] == 'commercial' ? 'commercial' : 'household'
      base_path = payload['base_path'].to_s
      order = payload['order'] || {}
      projects = Array(payload['projects'])

      unless base_path.empty? || File.directory?(base_path)
        begin
          require 'fileutils'
          FileUtils.mkdir_p(base_path)
        rescue SystemCallError => e
          return push_result(dlg, 'error', 'message' => "Не удалось создать папку #{base_path}: #{e.message}")
        end
      end
      if base_path.empty?
        return push_result(dlg, 'error', 'message' => 'Укажите корневую папку')
      end
      if projects.empty?
        return push_result(dlg, 'error', 'message' => 'Добавьте хотя бы один проект')
      end

      results = safe do
        settings = Settings.load
        timestamp = Generator.capture_timestamp(settings)
        # Бытовой заказ группируется в общую папку «Заказчик ~ Адрес».
        root = base_path
        if type == 'household'
          order_tpl = settings.dig('naming', 'household_order_folder') || '{customer} ~ {address}'
          order_folder = Generator.sanitize_filename(
            Generator.fill_template(order_tpl,
                                    'customer' => order['customer'].to_s, 'address' => order['address'].to_s)
          )
          root = File.join(base_path, order_folder)
        end

        created = projects.each_with_index.map do |project, index|
          Generator.create_project(settings,
                                   plug_root: PLUG_ROOT,
                                   base_path: root,
                                   type: type,
                                   order: type == 'commercial' ? order : order.merge('place' => project['place'].to_s),
                                   project: project,
                                   counter: index + 1,
                                   timestamp: timestamp)
        end
        created.each { |res| ProjectsStore.register(res['path']) }
        remember_root(base_path)
        created
      end

      push_result(dlg, 'created', 'results' => results)
      push_state(dlg)
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
