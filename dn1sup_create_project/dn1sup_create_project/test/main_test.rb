# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/main_test.rb — базовые тесты расширения.
# Запуск: внутри SketchUp через ext_test (MCP sketchup-dev);
# локально — ruby test/run_all.rb
# =============================================================================

require_relative 'test_helper'

module Dn1supCreateProject::Test
  test 'версия расширения задана' do
    assert(Dn1supCreateProject::VERSION =~ /\A\d+\.\d+\.\d+\z/,
           "VERSION=#{Dn1supCreateProject::VERSION.inspect}")
    registrar = File.join(File.dirname(Dn1supCreateProject::PLUG_ROOT), 'dn1sup_create_project.rb')
    if File.file?(registrar)
      m = File.read(registrar, encoding: 'UTF-8').match(/ext\.version\s*=\s*['"]([^'"]+)['"]/)
      assert(m, 'в регистраторе нет ext.version')
      assert_equal(Dn1supCreateProject::VERSION, m[1], 'версия регистратора ≠ VERSION')
    end
  end

  test 'модуль отвечает на команды' do
    assert(Dn1supCreateProject.respond_to?(:show_dialog), 'нет show_dialog')
    assert(Dn1supCreateProject.respond_to?(:unload!), 'нет unload! (нужен для ext_reload)')
    assert(Dn1supCreateProject.respond_to?(:setup!), 'нет setup!')
  end

  test 'PLUG_ROOT указывает на папку расширения' do
    assert(File.directory?(Dn1supCreateProject::PLUG_ROOT), Dn1supCreateProject::PLUG_ROOT)
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'main.rb')), 'нет main.rb рядом')
  end

  test 'шаблоны и иконка на месте' do
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'data', 'template.skp')), 'нет template.skp')
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'data', 'template.pur')), 'нет template.pur')
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'ui', 'index.html')), 'нет ui/index.html')
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'icons', 'cp_16.png')), 'нет иконки cp_16')
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'icons', 'cp_24.png')), 'нет иконки cp_24')
    assert(File.exist?(File.join(Dn1supCreateProject::PLUG_ROOT, 'icons', 'cp.svg')), 'нет иконки cp.svg')
  end
end
