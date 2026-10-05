# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/generator_test.rb — артикулы, санитизация,
# шаблоны имён, карточка проекта.
# =============================================================================

require_relative 'test_helper'

module Dn1supCreateProject::Test
  S = Dn1supCreateProject::Settings::DEFAULTS

  test 'артикул коммерческого проекта: префикс + время' do
    art = Dn1supCreateProject::Generator.build_articul(S, 'commercial', 1, '261005193000')
    assert_equal 'CF#261005193000', art
  end

  test 'артикул бытового проекта: префикс + время + номер с ведущим нулём' do
    g = Dn1supCreateProject::Generator
    assert_equal 'HF#26100519300001', g.build_articul(S, 'household', 1, '261005193000')
    assert_equal 'HF#26100519300011', g.build_articul(S, 'household', 11, '261005193000')
  end

  test 'перенумерация бытовых артикулов сохраняет метку времени' do
    projects = [{ 'articul' => 'x' }, { 'articul' => 'y' }, { 'articul' => 'z' }]
    Dn1supCreateProject::Generator.renumber_articuls(S, 'household', projects, '261005193000')
    assert_equal 'HF#26100519300001', projects[0]['articul']
    assert_equal 'HF#26100519300002', projects[1]['articul']
    assert_equal 'HF#26100519300003', projects[2]['articul']

    # коммерческие не перенумеровываются
    one = [{ 'articul' => 'CF#1' }]
    Dn1supCreateProject::Generator.renumber_articuls(S, 'commercial', one, '261005193000')
    assert_equal 'CF#1', one[0]['articul']
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

  test 'продукт: одиночный строкой, список через запятую (бытовой)' do
    g = Dn1supCreateProject::Generator
    assert_equal 'Стенка', g.product_value('commercial', ['Стенка'])
    assert_equal 'Шкаф, Полки', g.product_value('household', %w[Шкаф Полки])
    assert_equal 'Шкаф', g.product_value('household', ['Шкаф'])
    assert_equal '', g.product_value('household', [])
  end

  test 'имя проекта в карточке по формату старого генератора' do
    g = Dn1supCreateProject::Generator
    order = { 'customer' => 'Иван', 'company' => 'ООО Торг', 'address' => 'Минск', 'place' => 'ТЦ' }
    assert_equal 'ООО Торг, Остров | ТЦ, Минск', g.project_name('commercial', order: order, products: ['Остров'])
    household = { 'customer' => 'Иван', 'address' => 'Малиновка', 'place' => 'Кухня' }
    assert_equal 'Шкаф, Кухня | Иван, Малиновка', g.project_name('household', order: household, products: ['Шкаф'])
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
