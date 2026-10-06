# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/generator_test.rb — артикулы, санитизация,
# шаблоны имён, карточка проекта.
# =============================================================================

require_relative 'test_helper'

module Dn1supCreateProject::Test
  S = Dn1supCreateProject::Settings::DEFAULTS

  test 'артикул коммерческого проекта: префикс + время' do
    art = Dn1supCreateProject::Generator.build_articul(S, 'commercial', '261005_193000')
    assert_equal 'CF#261005_193000', art
  end

  test 'артикул бытового проекта: префикс + время, без счётчика' do
    g = Dn1supCreateProject::Generator
    assert_equal 'HF#261005_193000', g.build_articul(S, 'household', '261005_193000')
  end

  test 'метка времени по формату из настроек (ГГММДД_ЧЧММСС)' do
    g = Dn1supCreateProject::Generator
    time = Time.new(2026, 10, 5, 19, 30, 0)
    assert_equal '261005_193000', g.capture_timestamp(S, time)
  end

  test 'метки пачки: явная time_sec уважается, без метки — base + index' do
    g = Dn1supCreateProject::Generator
    stamp = Time.new(2026, 10, 5, 21, 45, 10).to_i
    base = Time.at(stamp - 10)
    times = g.project_times([{ 'time_sec' => stamp }, {}], base: base)
    assert_equal stamp, times[0].to_i
    assert_equal stamp - 9, times[1].to_i # base + index
  end

  test 'метки пачки: совпавшие секунды сдвигаются на +1 с' do
    g = Dn1supCreateProject::Generator
    stamp = Time.new(2026, 10, 5, 21, 45, 10).to_i
    base = Time.at(stamp - 10) # fallback не пересекается с явными метками
    times = g.project_times(
      [{ 'time_sec' => stamp }, { 'time_sec' => stamp }, {}],
      base: base
    )
    assert_equal stamp, times[0].to_i
    assert_equal stamp + 1, times[1].to_i
    assert_equal stamp - 8, times[2].to_i # base + 2, без сдвига
  end

  test 'санитизация имён: <> удаляются, запрещённые заменяются на _' do
    g = Dn1supCreateProject::Generator
    assert_equal 'Иван_Петров', g.sanitize_filename('Иван:Петров')
    assert_equal 'ТЦ_Малиновка', g.sanitize_filename('ТЦ_Малиновка')
    assert_equal 'a_b_c_d_e_f_g_h', g.sanitize_filename('a"b|c?d*e:f/g\\h')
    assert_equal 'Иванов Иван', g.sanitize_filename('Иванов <Иван>')
  end

  test 'шаблон имени: пустые сегменты ~ убираются' do
    g = Dn1supCreateProject::Generator
    tpl = '{articul} ~ {customer} ~ {company} ~ {address}, {place} ~ {product}'
    vars = { articul: 'CF#1', customer: 'Иван', company: '', address: 'Минск', place: 'ТЦ', product: 'Остров' }
    assert_equal 'CF#1 ~ Иван ~ Минск, ТЦ ~ Остров', g.fill_template(tpl, vars)
  end

  test 'шаблон имени: пустая запятая после адреса убирается' do
    g = Dn1supCreateProject::Generator
    tpl = '{customer} ~ {address} ~ {place}'
    vars = { customer: 'Иван', address: '', place: 'Кухня' }
    assert_equal 'Иван ~ Кухня', g.fill_template(tpl, vars)
  end

  test 'продукт: строка как есть, пустое — пустая строка' do
    g = Dn1supCreateProject::Generator
    assert_equal 'Стенка', g.product_value('commercial', 'Стенка')
    assert_equal 'Шкаф', g.product_value('household', ' Шкаф ')
    assert_equal '', g.product_value('household', '')
    assert_equal '', g.product_value('household', nil)
  end

  test 'имя проекта в карточке' do
    g = Dn1supCreateProject::Generator
    order = { 'customer' => 'Иван', 'company' => 'ООО Торг', 'address' => 'Минск', 'place' => 'ТЦ' }
    assert_equal 'ООО Торг, Остров | ТЦ, Минск', g.project_name('commercial', order: order, product: 'Остров')
    household = { 'customer' => 'Иван', 'address' => 'Малиновка', 'place' => 'Кухня' }
    assert_equal 'Шкаф, Кухня | Иван, Малиновка', g.project_name('household', order: household, product: 'Шкаф')
  end

  test 'карточка содержит телефон и почту заказчика' do
    g = Dn1supCreateProject::Generator
    card = g.build_card(S, type: 'commercial',
                        order: { 'customer' => 'Иван', 'company' => 'ООО Торг', 'phone' => '+375 29 111-22-33',
                                 'email' => 'ivan@mail.by', 'address' => 'Минск', 'place' => 'ТЦ' },
                        project: { 'place' => 'ТЦ' }, product: 'Остров', articul: 'CF#1')
    assert_equal '+375 29 111-22-33', card['phone']
    assert_equal 'ivan@mail.by', card['email']
  end

  test 'история проекта содержит стартовую запись как в старом формате' do
    history = Dn1supCreateProject::Generator.initial_history
    entry = history['project_history'].first
    assert_equal 'В разработке', entry['status']
    assert_equal 1, entry['version']
    assert_equal 1, entry['revision']
    assert_equal 'Предварительный эскиз проекта', entry['text']
    assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, entry['data'])
  end
end
