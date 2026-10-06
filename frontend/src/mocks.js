/**
 * mock-данные для разработки UI в браузере (вне SketchUp).
 * Зеркалит структуру настроек из settings.rb DEFAULTS.
 */

const DEFAULT_SETTINGS = {
  version: 2,
  defaults: { projects_root: 'U:/desktop/su_projects' },
  articul: { commercial_prefix: 'CF#', household_prefix: 'HF#', timestamp_format: '%y%m%d_%H%M%S' },
  structure: {
    templates: { skp: 'data/template.skp', pur: 'data/template.pur' },
    folders: {
      household: { order: '{customer} ~ {address}', project: '{place}' },
      commercial: { order: '{customer} ~ {company} ~ {address}', project: '{place} ~ {product}' }
    }
  },
  naming: {
    skp_file: '{place} ~ {product}',
    pur_file: '{articul}',
    yaml_file: '{articul}'
  },
  lists: {
    commercial_products: ['Торговый остров', 'Стойка ресепшн', 'Торговая мебель', 'Павильон'],
    places: ['Кухня', 'Гостиная', 'Прихожая', 'Спальня', 'Детская', 'Ванная', 'Кабинет', 'Балкон'],
    products_by_place: {
      'Кухня': ['Кухонный гарнитур', 'Кухонный остров', 'Буфет', 'Пенал', 'Барная стойка', 'Обеденный стол'],
      'Гостиная': ['Стенка', 'Тумба-ТВ', 'Шкаф', 'Витрина', 'Комод', 'Полки'],
      'Прихожая': ['Прихожая', 'Шкаф', 'Шкаф-купе', 'Обувница', 'Тумба', 'Полки'],
      'Спальня': ['Кровать', 'Шкаф', 'Шкаф-купе', 'Комод', 'Туалетный стол', 'Прикроватная тумба'],
      'Детская': ['Кровать', 'Шкаф', 'Стол письменный', 'Стеллаж', 'Комод', 'Полки'],
      'Ванная': ['Тумба под раковину', 'Шкаф-пенал', 'Зеркальный шкаф', 'Полки', 'Стеллаж'],
      'Кабинет': ['Стол письменный', 'Шкаф', 'Стеллаж', 'Тумба', 'Полки', 'Комод'],
      'Балкон': ['Шкаф', 'Стеллаж', 'Тумба', 'Полки', 'Рабочий стол']
    },
    other_products: ['Шкаф', 'Шкаф-купе', 'Стеллаж', 'Комод', 'Тумба', 'Полки']
  },
  files: {
    images: { folder: '_изображения', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tif', 'tiff'] },
    documents: { folder: '_документы', extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'rtf', 'odt', 'dwg'] }
  }
}

const root = 'U:/desktop/su_projects'

function mockProject(path, articul, type, place, product, description = '') {
  return {
    path,
    registered_at: '2026-10-01 10:00',
    unknown: false,
    name: `${product}, ${place} | Иванов Иван, Малиновка 5`,
    articul,
    type,
    place,
    product,
    description,
    files_count: 2
  }
}

const projects = [
  mockProject(
    `${root}/Иванов Иван ~ Малиновка 5/Кухня`,
    'HF#261001_120000', 'Бытовая', 'Кухня', 'Кухонный гарнитур',
    'Кухня в новостройке, потолки 2,7 м. Гарнитур прямой, техника Bosch. Срок — конец ноября.'
  ),
  mockProject(
    `${root}/Иванов Иван ~ ООО «Торг» ~ Минск/ТЦ «Малиновка» ~ Стойка ресепшн`,
    'CF#261002_093000', 'Коммерческая', 'ТЦ «Малиновка»', 'Стойка ресепшн'
  )
]

function detail(path) {
  const card = {
    path,
    project_name: 'Кухонный гарнитур, Кухня | Иванов Иван, Малиновка 5',
    project_type: 'Бытовая',
    articul: 'HF#26100112000001',
    customer_name: 'Иванов Иван',
    company_name: '',
    phone: '+375 29 111-22-33',
    email: 'ivanov@mail.by',
    address: 'Малиновка 5',
    place: 'Кухня',
    product: 'Кухонный гарнитур',
    description: 'Кухня в новостройке, потолки 2,7 м.',
    files: [
      { path: '_изображения/референс-кухня.jpg', category: 'image', description: 'Референс из Pinterest', added_at: '2026-10-02 12:00' },
      { path: '_документы/замер.pdf', category: 'document', description: 'Замер от 01.10', added_at: '2026-10-02 12:01' }
    ]
  }
  const history = {
    project_history: [
      { data: '2026-10-01 12:00', status: 'В разработке', version: 1, revision: 1, text: 'Предварительный эскиз проекта' },
      { data: '2026-10-02 12:01', status: 'Файлы', version: 1, revision: 2, text: 'Добавлено файлов: 2' }
    ]
  }
  return { card, history }
}

export const mockState = {
  root,
  settings: JSON.parse(JSON.stringify(DEFAULT_SETTINGS)),
  projects,
  settingsPath: '%APPDATA%/SketchUp/SketchUp 2026/dn1sup_create_project/settings.yaml',

  defaultSettings() {
    return JSON.parse(JSON.stringify(DEFAULT_SETTINGS))
  },

  payload() {
    return {
      version: '1.1.0',
      settings_path: this.settingsPath,
      settings: this.settings,
      projects: this.projects
    }
  },

  detail(path) {
    return detail(path)
  },

  setDetail(path, patch) {
    /* в mock достаточно ничего не делать */
  },

  mockProject
}
