# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/structure_test.rb — создание структуры на диске
# (заказ → проект), файловые группы, YAML-карточка, файлы, реестр.
# Работает во временной папке.
# =============================================================================

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'

module Dn1supCreateProject::Test
  G = Dn1supCreateProject::Generator
  P = Dn1supCreateProject::ProjectsStore
  F = Dn1supCreateProject::ProjectFiles

  def self.in_tmp
    Dir.mktmpdir('cp_test') do |tmp|
      data_dir = File.join(tmp, 'data_dir')
      yield tmp, data_dir
    end
  end

  test 'создание коммерческого проекта: заказ → проект → файлы → YAML' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      order = { 'customer' => 'Иван', 'company' => 'ООО Торг', 'address' => 'Минск',
                'phone' => '+375 29 111-22-33', 'email' => 'ivan@mail.by' }
      project = { 'place' => 'ТЦ Малиновка', 'product' => 'Торговый остров' }

      res = G.create_project(settings,
                             plug_root: Dn1supCreateProject::PLUG_ROOT,
                             base_path: tmp,
                             type: 'commercial',
                             order: order,
                             project: project)

      path = res['path']
      assert(Dir.exist?(path), "нет папки проекта: #{path}")
      # папка заказа 1-го уровня, внутри — папка проекта 2-го уровня
      assert_match(%r{/Иван ~ ООО Торг ~ Минск/ТЦ Малиновка ~ Торговый остров\z}, path)

      # подпапки больше не создаются автоматически
      subs = Dir.children(path).select { |c| Dir.exist?(File.join(path, c)) }
      assert(subs.empty?, "автоподпапок быть не должно, есть: #{subs.inspect}")

      assert(File.exist?(File.join(path, res['skp'])), 'нет .skp')
      assert_equal 'ТЦ Малиновка ~ Торговый остров.skp', res['skp']
      assert(File.exist?(File.join(path, res['pur'])), 'нет .pur')
      assert_equal 'ТЦ Малиновка.pur', res['pur']
      assert_equal 'ТЦ Малиновка.yaml', res['yaml']

      card, history = P.read_card(path)
      assert_nil(card['articul'], 'артикулов в карточке больше нет')
      assert_equal 'Коммерческая', card['project_type']
      assert_equal 'ООО Торг, Торговый остров | ТЦ Малиновка, Минск', card['project_name']
      assert_equal 'ООО Торг', card['company_name']
      assert_equal '+375 29 111-22-33', card['phone']
      assert_equal 'ivan@mail.by', card['email']
      assert_equal '', card['description']
      assert_equal [], card['files']
      assert_equal 1, history['project_history'].size
      assert_equal 'В разработке', history['project_history'].first['status']
    end
  end

  test 'создание бытового проекта: папка заказа и папка проекта' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      order = { 'customer' => 'Иван', 'address' => 'Малиновка 5' }

      res = G.create_project(settings,
                             plug_root: Dn1supCreateProject::PLUG_ROOT,
                             base_path: tmp,
                             type: 'household',
                             order: order,
                             project: { 'place' => 'Кухня', 'product' => 'Шкаф' })

      path = res['path']
      assert(Dir.exist?(path))
      assert_match(%r{/Иван ~ Малиновка 5/Кухня\z}, path)
      # .skp — «Место ~ Продукт», .pur — по месту
      assert_equal 'Кухня ~ Шкаф.skp', res['skp']
      assert_equal 'Кухня.pur', res['pur']

      card, = P.read_card(path)
      assert_equal 'Бытовая', card['project_type']
      assert_equal 'Шкаф', card['product']
      assert_equal 'Шкаф, Кухня | Иван, Малиновка 5', card['project_name']
    end
  end

  test 'файловые группы копируются в именованные папки проекта и в карточку' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      src_img = File.join(tmp, 'референс.jpg')
      src_doc = File.join(tmp, 'замер.pdf')
      File.write(src_img, 'img')
      File.write(src_doc, 'doc')

      res = G.create_project(settings,
                             plug_root: Dn1supCreateProject::PLUG_ROOT,
                             base_path: tmp,
                             type: 'household',
                             order: { 'customer' => 'Иван', 'address' => 'Малиновка' },
                             project: {
                               'place' => 'Гостиная', 'product' => 'Стенка',
                               'file_groups' => [
                                 { 'folder' => 'Фото мебели', 'paths' => [src_img] },
                                 { 'folder' => 'Замеры', 'paths' => [src_doc, File.join(tmp, 'нет_такого.pdf')] }
                               ]
                             })

      path = res['path']
      assert(File.file?(File.join(path, 'Фото мебели', 'референс.jpg')), 'картинка не в своей папке')
      assert(File.file?(File.join(path, 'Замеры', 'замер.pdf')), 'документ не в своей папке')

      card, = P.read_card(path)
      assert_equal 2, card['files'].size
      img = card['files'].find { |f| f['category'] == 'image' }
      doc = card['files'].find { |f| f['category'] == 'document' }
      assert_equal 'Фото мебели/референс.jpg', img['path']
      assert_equal 'Замеры/замер.pdf', doc['path']
    end
  end

  test 'повторное создание проекта в той же папке получает счётчик' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      order = { 'customer' => 'Иван', 'address' => 'Малиновка' }
      project = { 'place' => 'Кухня', 'product' => 'Шкаф' }

      first = G.create_project(settings, plug_root: Dn1supCreateProject::PLUG_ROOT,
                               base_path: tmp, type: 'household', order: order,
                               project: project)
      second = G.create_project(settings, plug_root: Dn1supCreateProject::PLUG_ROOT,
                                base_path: tmp, type: 'household', order: order,
                                project: project)
      third = G.create_project(settings, plug_root: Dn1supCreateProject::PLUG_ROOT,
                               base_path: tmp, type: 'household', order: order,
                               project: project)

      assert(first['path'] != second['path'], 'проекты не должны попадать в одну папку')
      assert_match(/Кухня \(2\)\z/, second['path'])
      assert_match(/Кухня \(3\)\z/, third['path'])
      assert(Dir.exist?(second['path']))
      assert(Dir.exist?(third['path']))
    end
  end

  test 'папка заказа для обоих типов (order_root)' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      comm = G.order_root(settings, 'commercial', tmp,
                          { 'customer' => 'Иван', 'company' => 'ООО Торг', 'address' => 'Минск' })
      hh = G.order_root(settings, 'household', tmp, { 'customer' => 'Иван', 'address' => 'Малиновка' })
      assert_equal 'Иван ~ ООО Торг ~ Минск', File.basename(comm)
      assert_equal 'Иван ~ Малиновка', File.basename(hh)
    end
  end

  test 'реестр проектов: регистрация, список, удаление' do
    in_tmp do |tmp, data_dir|
      project_path = File.join(tmp, 'CF#1')
      FileUtils.mkdir_p(project_path)

      entries = P.register(project_path, data_dir: data_dir)
      assert_equal 1, entries.size
      assert_equal project_path.tr('\\', '/'), entries.first['path']

      # повторная регистрация не дублирует
      entries = P.register(project_path, data_dir: data_dir)
      assert_equal 1, entries.size

      # список с данными карточки (карточки нет — unknown)
      list = P.list(data_dir: data_dir)
      assert_equal 1, list.size
      assert(list.first['unknown'], 'папка без карточки должна быть unknown')

      entries = P.unregister(project_path, data_dir: data_dir)
      assert_equal 0, entries.size
    end
  end

  test 'реестр: список проекта с карточкой отдаёт данные карточки' do
    in_tmp do |tmp, data_dir|
      project_path = File.join(tmp, 'ТЦ ~ Остров')
      FileUtils.mkdir_p(project_path)
      card = { 'project_name' => 'ООО Торг, Остров | ТЦ, Минск', 'project_type' => 'Коммерческая',
               'place' => 'ТЦ', 'product' => 'Остров',
               'customer_name' => 'Иван', 'company_name' => 'ООО Торг', 'address' => 'Минск',
               'description' => 'тест', 'files' => [{ 'path' => '_документы/a.pdf', 'category' => 'document' }] }
      P.write_card(project_path, card, { 'project_history' => [] })
      P.register(project_path, data_dir: data_dir)

      list = P.list(data_dir: data_dir)
      assert_equal 1, list.size
      entry = list.first
      assert_equal false, entry['unknown'], 'проект с карточкой не unknown'
      assert_nil(entry['articul'], 'артикулов в списке больше нет')
      assert_equal 'тест', entry['description']
      assert_equal 1, entry['files_count']
    end
  end

  test 'открытие unknown-папки создаёт минимальную карточку' do
    in_tmp do |tmp, _|
      project_path = File.join(tmp, 'Чужой проект')
      FileUtils.mkdir_p(project_path)

      card, history = P.open(project_path)
      assert_equal 'Чужой проект', card['project_name']
      assert_equal 'Регистрация', history['project_history'].first['status']
      assert(P.card_path(project_path), 'карточка не создана на диске')
    end
  end

  test 'добавление файлов: копирование в папки категорий и запись в карточку' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      project_path = File.join(tmp, 'proj')
      FileUtils.mkdir_p(project_path)

      src_img = File.join(tmp, 'референс.jpg')
      src_doc = File.join(tmp, 'замер.pdf')
      File.write(src_img, 'img')
      File.write(src_doc, 'doc')

      res = F.add_files(settings, project_path, [src_img, src_doc],
                        descriptions: { 'замер.pdf' => 'Замер от 01.10' })
      assert_equal 2, res['added'].size
      assert res['skipped'].empty?

      assert(File.file?(File.join(project_path, '_изображения', 'референс.jpg')), 'картинка не скопирована')
      assert(File.file?(File.join(project_path, '_документы', 'замер.pdf')), 'документ не скопирован')

      card, history = P.read_card(project_path)
      assert_equal 2, card['files'].size
      img = card['files'].find { |f| f['category'] == 'image' }
      doc = card['files'].find { |f| f['category'] == 'document' }
      assert_equal '_изображения/референс.jpg', img['path']
      assert_equal '_документы/замер.pdf', doc['path']
      assert_equal 'Замер от 01.10', doc['description']

      # история дополнена записью о файлах
      assert_equal 2, history['project_history'].size
      assert_equal 'Файлы', history['project_history'].last['status']
    end
  end

  test 'повторное добавление того же файла не перезаписывает оригинал' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      project_path = File.join(tmp, 'proj')
      FileUtils.mkdir_p(project_path)

      src = File.join(tmp, 'фото.png')
      File.write(src, 'a')

      F.add_files(settings, project_path, [src])
      F.add_files(settings, project_path, [src])

      assert(File.file?(File.join(project_path, '_изображения', 'фото.png')))
      assert(File.file?(File.join(project_path, '_изображения', 'фото (1).png')))
    end
  end

  test 'описание проекта сохраняется в карточке и в истории' do
    in_tmp do |tmp, _|
      project_path = File.join(tmp, 'proj')
      FileUtils.mkdir_p(project_path)

      assert(F.set_description(project_path, 'Кухня в новостройке'))
      card, history = P.read_card(project_path)
      assert_equal 'Кухня в новостройке', card['description']
      assert_equal 'Описание', history['project_history'].last['status']

      # повторное сохранение того же описания — no-op
      assert_equal false, F.set_description(project_path, 'Кухня в новостройке')
    end
  end

  test 'создание подпапки внутри проекта' do
    in_tmp do |tmp, _|
      project_path = File.join(tmp, 'proj')
      FileUtils.mkdir_p(project_path)

      created = F.create_subfolder(project_path, '_тендер')
      assert(Dir.exist?(created))
      assert_nil(F.create_subfolder(project_path, '   '), 'пустое имя не должно создавать папку')
    end
  end

  test 'настройки: недостающие ключи достраиваются из DEFAULTS' do
    Dir.mktmpdir('cp_test') do |tmp|
      data_dir = File.join(tmp, 'd')
      s = Dn1supCreateProject::Settings.load(data_dir: data_dir)
      s['structure']['folders']['household']['order'] = '{customer} — {address}'
      Dn1supCreateProject::Settings.save!(s, data_dir: data_dir)

      s2 = Dn1supCreateProject::Settings.load(data_dir: data_dir)
      assert_equal '{customer} — {address}', s2.dig('structure', 'folders', 'household', 'order'),
                   'пользовательское значение должно сохраниться'
      assert_equal '{place}', s2.dig('naming', 'pur_file'), 'остальные ключи — из DEFAULTS'
    end
  end

  test 'настройки v3: без артикулов, имена .pur/.yaml по месту' do
    s = Dn1supCreateProject::Settings::DEFAULTS
    assert_nil(s['articul'], 'секции артикулов в дефолтах больше нет')
    assert_equal '{customer} ~ {address}', s.dig('structure', 'folders', 'household', 'order')
    assert_equal '{place}', s.dig('structure', 'folders', 'household', 'project')
    assert_equal '{customer} ~ {company} ~ {address}', s.dig('structure', 'folders', 'commercial', 'order')
    assert_equal '{place} ~ {product}', s.dig('structure', 'folders', 'commercial', 'project')
    assert_equal '{place} ~ {product}', s.dig('naming', 'skp_file')
    assert_equal '{place}', s.dig('naming', 'pur_file')
    assert_equal '{place}', s.dig('naming', 'yaml_file')
    assert_nil(s.dig('structure', 'subfolders'), 'автоподпапки убраны из дефолтов')
  end

  test 'миграция настроек v2: articul удаляется, {articul} в именах заменяется' do
    Dir.mktmpdir('cp_test') do |tmp|
      data_dir = File.join(tmp, 'd')
      FileUtils.mkdir_p(data_dir)
      old = {
        'version' => 2,
        'articul' => { 'commercial_prefix' => 'CF#', 'timestamp_format' => '%y%m%d_%H%M%S' },
        'naming' => { 'skp_file' => '{place}', 'pur_file' => '{articul}', 'yaml_file' => '{articul}' }
      }
      File.write(File.join(data_dir, 'settings.yaml'), YAML.dump(old), encoding: 'UTF-8')

      s = Dn1supCreateProject::Settings.load(data_dir: data_dir)
      assert_nil(s['articul'], 'устаревшая секция артикулов удаляется при чтении')
      assert_equal '{place}', s.dig('naming', 'pur_file'), 'старый шаблон {articul} заменяется'
      assert_equal '{place}', s.dig('naming', 'yaml_file')
      assert_equal '{place}', s.dig('naming', 'skp_file'), 'пользовательские шаблоны без {articul} не трогаем'
    end
  end

  test 'поиск карточки поддерживает расширения .yaml и .yml' do
    in_tmp do |tmp, _|
      proj = File.join(tmp, 'yml_proj')
      FileUtils.mkdir_p(proj)
      yml_card = File.join(proj, 'card.yml')
      File.write(yml_card, YAML.dump('project_name' => 'Тест YML', 'place' => 'Кухня'), encoding: 'UTF-8')

      assert_equal yml_card, P.card_path(proj)
      card, = P.read_card(proj)
      assert_equal 'Тест YML', card['project_name']
    end
  end

  test 'поиск карточки находит старый формат с ключом articul' do
    in_tmp do |tmp, _|
      proj = File.join(tmp, 'old_proj')
      FileUtils.mkdir_p(proj)
      old_card = File.join(proj, 'HF#261005_193000.yaml')
      File.write(old_card, YAML.dump('articul' => 'HF#261005_193000', 'project_name' => 'Старый проект'),
                 encoding: 'UTF-8')

      assert_equal old_card, P.card_path(proj), 'старые карточки (с articul) должны находиться'
      card, = P.read_card(proj)
      assert_equal 'Старый проект', card['project_name']
    end
  end

  test 'получение списка подпапок проекта' do
    in_tmp do |tmp, _|
      proj = File.join(tmp, 'sub_proj')
      FileUtils.mkdir_p(File.join(proj, '_изображения'))
      FileUtils.mkdir_p(File.join(proj, '_документы'))
      FileUtils.mkdir_p(File.join(proj, '.hidden'))

      subs = P.list_subfolders(proj)
      assert_equal %w[_документы _изображения], subs
    end
  end
end
