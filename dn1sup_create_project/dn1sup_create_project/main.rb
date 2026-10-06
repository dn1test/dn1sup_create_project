# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/main.rb — основная логика расширения «DN1SUP Create Project».
#
# Код рассчитан на горячую перезагрузку (ext_reload MCP-сервера sketchup-dev):
#   • диалоги регистрируются через track_* и снимаются в unload! — старая
#     версия не оставляет следов;
#   • меню и тулбар создаются один раз на сессию SketchUp: UI::Menu в
#     современных версиях не имеет API удаления, поэтому пункты ссылаются
#     на Dn1supCreateProject.* через константу и после перезагрузки вызывают
#     уже новый код.
# =============================================================================

begin
  require 'sketchup.rb'
rescue LoadError
  # загрузка в обычном Ruby — только для локального запуска тестов
end

%w[settings generator projects_store files win_shell dialog].each do |name|
  require File.join(File.dirname(__FILE__), "#{name}.rb")
end
begin
  dev_file = File.join(File.dirname(__FILE__), 'dev_updater.rb')
  require dev_file if File.file?(dev_file)
rescue LoadError
  nil
end

module Dn1sup
  def self.common_menu
    @common_menu ||= begin
      legacy = (defined?($dn1sup_common_menu) && $dn1sup_common_menu) || (defined?($dn1sup_menu) && $dn1sup_menu)
      legacy || UI.menu('Extensions').add_submenu('DN1SUP')
    end
  end
end

module Dn1supCreateProject
  VERSION   = '1.2.1'.freeze
  PLUG_ROOT = File.dirname(__FILE__).freeze

  COMMON_MENU = 'DN1SUP'.freeze          # общее меню всех расширений DN1Sup
  MENU_NAME   = 'Create Project'.freeze  # подменю расширения внутри COMMON_MENU

  TOOLBAR_NAME = 'DN1SUP Create Project'.freeze
  CMD_TOOLTIP  = 'DN1SUP Create Project — создание и оформление проектов'.freeze

  class << self
    # -- отслеживаемые ресурсы (снимаются в unload!) ---------------------------

    def dialogs; @dialogs ||= []; end # [UI::HtmlDialog, ...]

    def track_dialog(dialog)
      dialogs << dialog
      dialog
    end

    # -- выгрузка: вызвать ПЕРЕД remove_const (это делает ext_reload) ----------
    # Меню здесь не трогаем: UI::Menu не имеет API удаления, пункты живут
    # всю сессию и продолжают работать, ссылаясь на константу модуля.

    def unload!
      dialogs.each do |dialog|
        begin
          dialog.close
        rescue StandardError
          nil
        end
      end
      true
    end

    # -- построение интерфейса --------------------------------------------------

    def setup!
      return if @setup_done
      return unless defined?(UI) && UI.respond_to?(:menu)

      @setup_done = true
      setup_ui
    end

    # Меню и панель инструментов создаются один раз на сессию SketchUp
    # (см. комментарий выше). Своё подменю внутри общего меню DN1SUP.
    def setup_ui
      return if @menu_created || (defined?(Dn1sup) && Dn1sup.instance_variable_get(:@cp_menu))

      common = Dn1sup.common_menu
      menu = common.add_submenu(MENU_NAME)
      @menu_created = true
      Dn1sup.instance_variable_set(:@cp_menu, menu) if defined?(Dn1sup)

      cmd_open = UI::Command.new('Создать проект...') do
        Dn1supCreateProject.safe { Dn1supCreateProject.show_dialog }
      end
      cmd_open.menu_text = 'Создать проект...'
      cmd_open.tooltip = CMD_TOOLTIP
      cmd_open.status_bar_text = 'Создание и оформление мебельных проектов'
      menu.add_item(cmd_open)

      menu.add_item('Открыть папку настроек') { Dn1supCreateProject.safe { WinShell.reveal(Settings.path) } }
      menu.add_separator
      menu.add_item('🔄 Обновить из dev-папки') { Dn1supCreateProject.safe { Dn1supCreateProject.update_from_dev } }
      menu.add_item('⚡ Перезагрузить (Hot Reload)') { Dn1supCreateProject.safe { Dn1supCreateProject.hot_reload } }
      menu.add_separator
      menu.add_item('О расширении') { Dn1supCreateProject.about }

      setup_toolbar
    end

    # Панель инструментов с кнопкой запуска диалога. Тулбар нельзя удалить
    # через API, поэтому кнопка создаётся один раз: после горячей перезагрузки
    # UI::Toolbar.new возвращает существующую панель, а блок старой кнопки
    # ссылается на константу модуля — уже новый код.
    def setup_toolbar
      toolbar = UI::Toolbar.new(TOOLBAR_NAME)
      return if toolbar.any? { |c| c.tooltip == CMD_TOOLTIP }

      cmd = UI::Command.new('Создать проект') do
        Dn1supCreateProject.show_dialog if defined?(Dn1supCreateProject)
      end
      cmd.menu_text = 'Создать проект...'
      cmd.tooltip = CMD_TOOLTIP
      cmd.status_bar_text = 'Создание и оформление мебельных проектов'
      svg = File.join(PLUG_ROOT, 'icons', 'cp.svg')
      if File.exist?(svg) && defined?(Sketchup) && Sketchup.respond_to?(:version) && Sketchup.version.to_i >= 16
        cmd.small_icon = svg
        cmd.large_icon = svg
      else
        cmd.small_icon = File.join(PLUG_ROOT, 'icons', 'cp_16.png')
        cmd.large_icon = File.join(PLUG_ROOT, 'icons', 'cp_24.png')
      end
      toolbar.add_item(cmd)
      toolbar.restore
    rescue StandardError => e
      puts "[CreateProject] Не удалось создать панель инструментов: #{e.message}"
    end

    def update_from_dev(dev_dir = nil)
      return unless defined?(DevUpdater)
      was_open = @dialog && @dialog.visible?
      DevUpdater.update_and_reload!(dev_dir: dev_dir, reopen_dialog: was_open, notify: true)
    end

    def hot_reload
      return unless defined?(DevUpdater)
      DevUpdater.reload!
      UI.messagebox("⚡ Create Project v#{VERSION} перезагружен!") if defined?(UI)
    end

    def about
      UI.messagebox(
        "Create Project v#{VERSION}\n\n" \
        "Создание и оформление мебельных проектов.\n" \
        "Структура папок, YAML-карточка проекта, картинки и документы.\n\n" \
        "Настройки: #{Settings.path}"
      )
    end

    # Ошибки команд не должны ронять SketchUp — показываем их пользователю.
    def safe
      yield
    rescue StandardError => e
      UI.messagebox("Create Project: #{e.class}: #{e.message}")
      puts "[CreateProject] #{e.class}: #{e.message}"
      puts e.backtrace.first(5) if e.backtrace
    end
  end
end

Dn1supCreateProject.setup!
