# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project.rb — регистратор расширения «DN1SUP Create Project»
# (единственный файл в корне Plugins). SketchUp автозагружает top-level .rb
# при старте; весь код лежит рядом в подпапке dn1sup_create_project/.
#
# Регистратор идемпотентен: повторный load (горячая перезагрузка через
# ext_reload) не дублирует запись в Extension Manager — main.rb при этом
# загружается отдельным load (см. ext_reload MCP-сервера sketchup-dev).
# =============================================================================

require 'sketchup.rb'
require 'extensions.rb'

# ExtensionManager не включает Enumerable — только each/[]/size.
_registered = false
Sketchup.extensions.each { |e| _registered = true if e.name == "DN1SUP Create Project" }

unless _registered
  ext = SketchupExtension.new("DN1SUP Create Project", File.join('dn1sup_create_project', 'main'))
  ext.description = "Создание и оформление мебельных проектов: структура папок, карточка YAML, картинки и документы"
  ext.version     = '1.2.0'
  ext.creator     = "DN1Sup"
  ext.copyright   = '2026, DN1Sup'
  Sketchup.register_extension(ext, true) # true = загружать при старте SketchUp
end
