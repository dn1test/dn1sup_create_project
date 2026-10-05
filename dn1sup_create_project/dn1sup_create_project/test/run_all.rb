# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/run_all.rb — локальный запуск всех тестов
# (в обычном Ruby, без SketchUp). Модельные тесты помечаются skip.
# Запуск: ruby test/run_all.rb
# =============================================================================

require_relative 'test_helper'

Dir.glob(File.join(__dir__, '*_test.rb')).sort.each do |file|
  next if File.basename(file) == 'main_test.rb' # main_test грузится первым

  require file
end

report = Dn1supCreateProject::Test.run!

puts '————————————————————————————————————'
puts "Тестов: #{report['total']}  Прошло: #{report['passed']}  " \
      "Провалено: #{report['failures'].size}  Пропущено: #{report['skipped'].size}  " \
      "за #{report['duration_ms']} мс"

report['failures'].each do |failure|
  puts "\n✗ #{failure['name']}\n  #{failure['error']}"
  Array(failure['backtrace']).each { |line| puts "    #{line}" }
end
report['skipped'].each { |s| puts "  ⊘ #{s['name']}: #{s['reason']}" }

exit(report['failures'].empty? ? 0 : 1)
