# frozen_string_literal: true
# =============================================================================
# dn1sup_create_project/test/structure_test.rb — создание структуры на диске,
# YAML-карточка, файлы проекта, реестр. Работает во временной папке.
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

  test 'создание коммерческого проекта: папки, файлы, YAML' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      order = { 'customer' => 'Иван', 'company' => 'ООО Торг', 'address' => 'Минск' }
      project = { 'place' => 'ТЦ Малиновка', 'products' => ['Торговый остров'] }

      res = G.create_project(settings,
                             plug_root: Dn1supCreateProject::PLUG_ROOT,
                             base_path: tmp,
                             type: 'commercial',
                             order: order,
                             project: project,
                             counter: 1,
                             timestamp: '261005193000')

      path = res['path']
      assert(Dir.exist?(path), "нет папки проекта: #{path}")
      assert_match(/CF#261005193000 ~ Иван ~ ООО Торг ~ Минск, ТЦ Малиновка ~ Торговый остров\z/, path)

      settings.dig('structure', 'subfolders').each do |sub|
        assert(Dir.exist?(File.join(path, sub)), "нет подпапки #{sub}")
      end

      assert(File.exist?(File.join(path, res['skp'])), 'нет .skp')
      assert(File.exist?(File.join(path, res['pur'])), 'нет .pur')
      assert(File.exist?(File.join(path, res['yaml'])), 'нет .yaml')

      card, history = P.read_card(path)
      assert_equal 'CF#261005193000', card['articul']
      assert_equal 'Коммерческая', card['project_type']
      assert_equal 'ООО Торг, Торговый остров | ТЦ Малиновка, Минск', card['project_name']
      assert_equal 'ООО Торг', card['company_name']
      assert_equal '', card['description']
      assert_equal [], card['files']
      assert_equal 1, history['project_history'].size
      assert_equal 'В разработке', history['project_history'].first['status']
    end
  end

  test 'создание бытового заказа: общая папка и подпапка проекта' do
    in_tmp do |tmp, _|
      settings = Dn1supCreateProject::Settings.load
      order = { 'customer' => 'Иван', 'address' => 'Малиновка 5' }
      order_folder = G.sanitize_filename(G.fill_template('{customer} ~ {address}',
                                                         'customer' => 'Иван', 'address' => 'Малиновка 5'))

      res = G.create_project(settings,
                             plug_root: Dn1supCreateProject::PLUG_ROOT,
                             base_path: File.join(tmp, order_folder),
                             type: 'household',
                             order: order.merge('place' => 'Кухня'),
                             project: { 'place' => 'Кухня', 'products' => %w[Шкаф Полки] },
                             counter: 2,
                             timestamp: '261005193000')

      path = res['path']
      assert(Dir.exist?(path))
      assert_match(/HF#26100519300002 ~ Кухня\z/, path)
      # бытовое имя .skp: Заказчик ~ Адрес ~ Место
      assert_equal 'Иван ~ Малиновка 5 ~ Кухня.skp', res['skp']
      assert_equal 'HF#26100519300002.pur', res['pur']

      card, = P.read_card(path)
      assert_equal 'Бытовая', card['project_type']
      assert_equal 'Шкаф, Полки', card['product']
      assert_equal 'Шкаф, Полки, Кухня | Иван, Малиновка 5', card['project_name']
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
      project_path = File.join(tmp, 'CF#261005193000 ~ Иван')
      FileUtils.mkdir_p(project_path)
      card = { 'project_name' => 'ООО Торг, Остров | ТЦ, Минск', 'project_type' => 'Коммерческая',
               'articul' => 'CF#261005193000', 'place' => 'ТЦ', 'product' => 'Остров',
               'customer_name' => 'Иван', 'company_name' => 'ООО Торг', 'address' => 'Минск',
               'description' => 'тест', 'files' => [{ 'path' => '_документы/a.pdf', 'category' => 'document' }] }
      P.write_card(project_path, card, { 'project_history' => [] })
      P.register(project_path, data_dir: data_dir)

      list = P.list(data_dir: data_dir)
      assert_equal 1, list.size
      entry = list.first
      assert_equal false, entry['unknown'], 'проект с карточкой не unknown'
      assert_equal 'CF#261005193000', entry['articul']
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
      s['structure']['subfolders'] = ['_только_своя']
      Dn1supCreateProject::Settings.save!(s, data_dir: data_dir)

      s2 = Dn1supCreateProject::Settings.load(data_dir: data_dir)
      assert_equal ['_только_своя'], s2['structure']['subfolders'], 'пользовательское значение должно сохраниться'
      assert_equal 'CF#', s2.dig('articul', 'commercial_prefix'), 'остальные ключи — из DEFAULTS'
    end
  end
end
