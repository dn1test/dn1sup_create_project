# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/win_shell.rb — открытие файлов и папок средствами
# Windows. UI.openURL не открывает file:// URL (возвращает false), поэтому
# Проводник запускаем через ShellExecuteW (не Windows — no-op).
# Здесь же мультивыбор файлов: UI.openpanel выбирает только один файл, поэтому
# диалог — PowerShell OpenFileDialog с Multiselect. Перехват stdout дочерних
# процессов в SketchUp не работает, поэтому пути передаются через временный
# файл (base64-UTF8, чтобы не зависеть от кодовой страницы консоли).
# =============================================================================

require 'base64'
require 'open3'
require 'tmpdir'

module Dn1supCreateProject
  module WinShell
    extend self

    begin
      require 'fiddle/import'

      module API
        extend Fiddle::Importer
        dlload 'shell32.dll'
        extern 'void* ShellExecuteW(void*, const void*, const void*, const void*, const void*, int)'
      end

      SUPPORTED = true
    rescue LoadError, StandardError
      SUPPORTED = false
    end

    SW_SHOWNORMAL = 1

    # Открыть папку в Проводнике (файл выделен, если передан файл).
    # true — окно запрошено.
    def reveal(path)
      return false unless SUPPORTED
      return false if path.nil? || path.to_s.empty?

      ret = API.ShellExecuteW(nil, nil,
                              wide('explorer.exe'),
                              wide(%(/select,"#{path.tr('/', '\\')}")),
                              nil, SW_SHOWNORMAL)
      ret.to_i > 32
    rescue StandardError
      false
    end

    # Открыть файл приложением по умолчанию (картинка, PDF, документ).
    def open_file(path)
      return false unless SUPPORTED
      return false unless File.file?(path.to_s)

      ret = API.ShellExecuteW(nil, wide('open'),
                              wide(path.to_s.tr('/', '\\')),
                              nil, nil, SW_SHOWNORMAL)
      ret.to_i > 32
    rescue StandardError
      false
    end

    # Открыть папку (для файла — его папку).
    def open_folder(path)
      target = path.to_s
      target = File.dirname(target) if File.file?(target)
      return false unless File.directory?(target)
      return false unless SUPPORTED

      ret = API.ShellExecuteW(nil, wide('open'),
                              wide(target.tr('/', '\\')),
                              nil, nil, SW_SHOWNORMAL)
      ret.to_i > 32
    rescue StandardError
      false
    end

    # Мультивыбор файлов нативным диалогом Windows. Возвращает массив полных
    # путей ([] — отмена или не Windows).
    def pick_files_multi(title, filter)
      return [] unless win?

      out_file = File.join(Dir.tmpdir, "cp_pick_#{Process.pid}_#{Time.now.to_i}_#{rand(10_000)}.b64")
      script = <<~PS
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        $owner.ShowInTaskbar = $false
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Multiselect = $true
        $dlg.Title = '#{ps_escape(title)}'
        $dlg.Filter = '#{ps_escape(filter)}'
        if ($dlg.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) {
          [IO.File]::WriteAllText('#{ps_escape(out_file)}', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($dlg.FileNames -join "`n")))
        }
      PS
      encoded = Base64.strict_encode64(script.encode('UTF-16LE'))
      return [] unless run_powershell_hidden(encoded)

      paths = []
      if File.exist?(out_file)
        paths = Base64.decode64(File.read(out_file)).force_encoding(Encoding::UTF_8)
                        .split("\n").map(&:strip).reject(&:empty?)
      end
      File.delete(out_file) if File.exist?(out_file)
      paths
    end

  private

  # LPCWSTR: UTF-16LE с нулевым терминатором
  def wide(str)
    (str + "\0").encode('UTF-16LE')
  end

  def win?
    Gem.win_platform?
  end

  def ps_escape(text)
    text.to_s.gsub("'", "''")
  end

  # Запуск powershell без окна консоли: WScript.Shell.Run(окно=0, ждать=true).
  # Open3 здесь не годится — у SketchUp нет консоли, и powershell.exe получает
  # собственную видимую консоль (чёрное окно на время выбора файлов).
  def run_powershell_hidden(encoded_command)
    require 'win32ole'
    shell = WIN32OLE.new('WScript.Shell')
    shell.Run("powershell.exe -NoProfile -STA -EncodedCommand #{encoded_command}", 0, true) == 0
  rescue StandardError, ScriptError
    _out, status = Open3.capture2('powershell.exe', '-NoProfile', '-STA', '-EncodedCommand', encoded_command)
    status&.success?
  end
  end
end
