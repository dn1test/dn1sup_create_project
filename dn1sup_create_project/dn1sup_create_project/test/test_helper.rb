# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/test_helper.rb — мини-харнесс тестов
# «DN1SUP Create Project».
#
# Работает в двух средах:
#   • внутри SketchUp — запуск через ext_test MCP-сервера sketchup-dev;
#   • в обычном Ruby — ruby test/run_all.rb (юнит-тесты логики).
#
# Намеренно НЕ minitest/autorun: у него at_exit-хуки и накопление классов
# между повторными запусками в одном процессе SketchUp. Харнесс можно
# перезапускать сколько угодно (run! сам очищает список).
# =============================================================================

require_relative '../main' unless defined?(Dn1supCreateProject::VERSION)

module Dn1supCreateProject
  module Test
    class Failure < StandardError; end
    class Skip    < StandardError; end

    @tests = []

    class << self
      attr_reader :tests

      def test(name, &block)
        @tests << [name, block]
      end

      def assert(condition, msg = 'утверждение ложно')
        raise Failure, msg unless condition
      end

      def assert_equal(expected, actual, msg = nil)
        return if expected == actual

        raise Failure, "#{msg ? "#{msg}: " : ''}ожидали #{expected.inspect}, получили #{actual.inspect}"
      end

      def assert_nil(actual, msg = nil)
        assert(actual.nil?, "#{msg ? "#{msg}: " : ''}ожидали nil, получили #{actual.inspect}")
      end

      def assert_match(pattern, text, msg = nil)
        raise Failure, "#{msg ? "#{msg}: " : ''}#{text.inspect} не соответствует #{pattern.inspect}" unless text.to_s.match?(pattern)
      end

      def skip(reason = 'пропуск')
        raise Skip, reason
      end

      # Выполняет все зарегистрированные тесты, возвращает хеш-отчёт и
      # очищает список (повторный run! стартует с чистого листа).
      # Ключи отчёта — СТРОЧНЫЕ: через мост (TCP/JSON) Symbol-ключи
      # превращаются в ":total" и клиент их не находит.
      def run!
        results = { 'total' => @tests.size, 'failures' => [], 'skipped' => [] }
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @tests.each do |name, block|
          begin
            block.call
          rescue Skip => e
            results['skipped'] << { 'name' => name, 'reason' => e.message }
          rescue Failure => e
            results['failures'] << { 'name' => name, 'error' => e.message }
          rescue Exception => e # rubocop:disable Lint/RescueException
            results['failures'] << { 'name' => name, 'error' => "#{e.class}: #{e.message}",
                                     'backtrace' => Array(e.backtrace).first(5) }
          end
        end
        results['duration_ms'] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
        results['passed'] = results['total'] - results['failures'].size - results['skipped'].size
        reset!
        results
      end

      def reset!
        @tests = []
      end
    end
  end
end
