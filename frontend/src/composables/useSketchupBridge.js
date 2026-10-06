import { reactive } from 'vue'
import { mockState } from '../mocks'

/**
 * Мост Ruby ↔ JS (единый паттерн с dn1sup_time_project2):
 *  — JS → Ruby: sketchup.call_ruby(name, param) — один экшен-колбэк 'call_ruby';
 *  — Ruby → JS: window.pushState(state) и window.pushResult(kind, payload).
 *
 * Вне SketchUp (npm run dev в браузере) включается mock-режим.
 */

function getSketchup() {
  if (typeof sketchup !== 'undefined' && sketchup && typeof sketchup.call_ruby === 'function') {
    return sketchup
  }
  if (typeof window !== 'undefined' && window.sketchup && typeof window.sketchup.call_ruby === 'function') {
    return window.sketchup
  }
  return null
}

const isMock = !getSketchup()

// -- общее состояние UI -------------------------------------------------------

const state = reactive({
  ready: false,
  version: '…',
  settingsPath: '',
  settings: null,   // настройки из Ruby (settings.yaml)
  projects: [],     // реестр проектов
  selected: null,   // открытый проект: { path, card, history }
  toast: null,      // { kind: 'ok' | 'err', text }
  orderType: null,  // тип заказа на вкладке «Создать»: 'commercial' | 'household' | null (вопрос при открытии)
  lastCreated: 0    // Date.now() последнего успешного создания проектов (сигнал вкладке «Создать» очистить форму)
})

let toastTimer = null
function toast(kind, text) {
  state.toast = { kind, text }
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { state.toast = null }, 4000)
}

// -- обработчики пушей Ruby (регистрируются до монтирования Vue) --------------

const resultHandlers = new Map() // kind -> Set<fn>
const pickResolvers = new Map()  // purpose -> fn(path)

function emitResult(kind, payload) {
  if (kind === 'error') {
    toast('err', payload.message || 'Ошибка Ruby')
    return
  }
  if (kind === 'settings_saved') toast('ok', 'Настройки сохранены')
  if (kind === 'template_added') toast('ok', `Шаблон .${payload.kind} обновлён`)
  if (kind === 'created' && payload.results) {
    toast('ok', `Создано проектов: ${payload.results.length}`)
    state.lastCreated = Date.now()
  }
  if (kind === 'subfolder_created') toast('ok', `Папка «${payload.name || ''}» создана`)
  if (kind === 'add_files') {
    const n = (payload.added || []).length
    const skipped = (payload.skipped || []).length
    toast(n ? 'ok' : 'err', skipped ? `Добавлено: ${n}, с ошибками: ${skipped}` : `Добавлено файлов: ${n}`)
  }

  if (kind === 'pick_folder') {
    const resolve = pickResolvers.get(payload.purpose)
    if (resolve) {
      pickResolvers.delete(payload.purpose)
      resolve(payload.path || '')
    }
  }
  if (kind === 'pick_files') {
    const resolve = pickResolvers.get(payload.purpose)
    if (resolve) {
      pickResolvers.delete(payload.purpose)
      resolve(payload.paths || [])
    }
  }
  if (kind === 'pick_folder_files') {
    const resolve = pickResolvers.get(payload.purpose)
    if (resolve) {
      pickResolvers.delete(payload.purpose)
      resolve(payload)
    }
  }

  const set = resultHandlers.get(kind)
  if (set) set.forEach(fn => { try { fn(payload) } catch (e) { console.warn(e) } })
}

if (typeof window !== 'undefined') {
  window.pushState = function (payload) {
    if (!payload) return
    state.ready = true
    state.version = payload.version || '—'
    state.settingsPath = payload.settings_path || ''
    state.settings = payload.settings || null
    state.projects = payload.projects || []
  }
  window.pushResult = function (kind, payload) {
    emitResult(kind, payload || {})
  }
}

// -- вызовы Ruby ---------------------------------------------------------------

let seq = 0
function callRuby(name, param) {
  const bridge = getSketchup()
  if (bridge) {
    try {
      bridge.call_ruby(name, param === undefined ? '' : String(param))
      return true
    } catch (e) {
      console.warn('callRuby error:', e)
    }
  }
  return false
}

function callRubyJson(name, obj) {
  return callRuby(name, JSON.stringify(obj))
}

/** Открыть папку выбором в системном диалоге. purpose — метка вызывающего. */
export function pickFolder(purpose) {
  return new Promise((resolve) => {
    if (isMock) {
      const p = window.prompt('Путь к папке (mock):', mockState.root)
      resolve(p || '')
      return
    }
    pickResolvers.set(purpose, resolve)
    callRuby('pick_folder', purpose)
    // страховка: если ответ не пришёл за 2 минуты — отпускаем
    setTimeout(() => {
      if (pickResolvers.has(purpose)) {
        pickResolvers.delete(purpose)
        resolve('')
      }
    }, 120000)
  })
}

/** Нативный мультивыбор файлов (Ruby возвращает массив полных путей). */
export function pickFiles(purpose) {
  return new Promise((resolve) => {
    if (isMock) {
      const raw = window.prompt('Пути к файлам через ; (mock):', '')
      resolve(raw ? raw.split(';').map(s => s.trim()).filter(Boolean) : [])
      return
    }
    pickResolvers.set(purpose, resolve)
    callRuby('pick_files', purpose)
    // страховка: если ответ не пришёл за 5 минут — отпускаем
    setTimeout(() => {
      if (pickResolvers.has(purpose)) {
        pickResolvers.delete(purpose)
        resolve([])
      }
    }, 300000)
  })
}

/** Нативный выбор папки: Ruby возвращает { paths, folder_name } или null. */
export function pickFolderFiles(purpose) {
  return new Promise((resolve) => {
    if (isMock) {
      resolve(null)
      return
    }
    pickResolvers.set(purpose, resolve)
    callRuby('pick_folder_files', purpose)
    setTimeout(() => {
      if (pickResolvers.has(purpose)) {
        pickResolvers.delete(purpose)
        resolve(null)
      }
    }, 120000)
  })
}

/** Выбрать файл-шаблон (.skp/.pur) нативным диалогом — Ruby копирует в data/. */
export function pickTemplate(kind) {
  if (isMock) {
    toast('ok', `Шаблон .${kind} обновлён (mock)`)
    return
  }
  callRuby('pick_template', kind)
}

export function onResult(kind, fn) {
  if (!resultHandlers.has(kind)) resultHandlers.set(kind, new Set())
  resultHandlers.get(kind).add(fn)
  return () => resultHandlers.get(kind).delete(fn)
}

export function loadState() {
  if (isMock) {
    setTimeout(() => window.pushState(mockState.payload()), 150)
    return
  }
  callRuby('get_state')
}

export function registerExisting() {
  if (isMock) {
    const p = window.prompt('Путь к существующему проекту (mock):', mockState.root + '/HF#26010100000001 ~ Кухня')
    if (p) {
      mockState.projects.push(mockState.mockProject(p, 'HF#26010100000001', 'Бытовая', 'Кухня', 'Кухонный гарнитур'))
      window.pushState(mockState.payload())
    }
    return
  }
  callRuby('register_existing')
}

export function unregisterProject(path) {
  if (isMock) {
    mockState.projects = mockState.projects.filter(p => p.path !== path)
    window.pushState(mockState.payload())
    return
  }
  callRuby('unregister_project', path)
}

export function createProjects(payload) {
  if (isMock) {
    const root = payload.base_path || mockState.settings.defaults.projects_root
    window.pushResult('created', { results: payload.projects.map((p, i) => ({ path: `${root}/Art${i + 1}` })) })
    setTimeout(() => window.pushState(mockState.payload()), 200)
    return
  }
  callRubyJson('create_projects', payload)
}

export function openProject(path) {
  if (isMock) {
    window.pushResult('project', mockState.detail(path))
    return
  }
  callRuby('get_project', path)
}

export function saveDescription(path, description) {
  if (isMock) {
    mockState.setDetail(path, { description })
    toast('ok', 'Описание сохранено')
    return
  }
  callRubyJson('save_description', { path, description })
}

/** paths — локальные пути из <input type="file"> (use_file_input). */
export function addFiles(path, paths, category) {
  if (isMock) {
    window.pushResult('add_files', { added: paths.map(p => ({ path: p })), skipped: [] })
    return
  }
  callRubyJson('add_files', { path, paths, category })
}

export function removeFile(path, relPath, deleteFromDisk) {
  if (isMock) { toast('ok', 'Файл убран (mock)'); return }
  callRubyJson('remove_file', { path, rel_path: relPath, delete_from_disk: !!deleteFromDisk })
}

export function setFileDescription(path, relPath, description) {
  if (isMock) { toast('ok', 'Описание файла сохранено (mock)'); return }
  callRubyJson('set_file_description', { path, rel_path: relPath, description })
}

export function createSubfolder(path, name) {
  if (isMock) { toast('ok', `Папка «${name}» создана (mock)`); return }
  callRubyJson('create_subfolder', { path, name })
}

export function openFolder(path) {
  if (isMock) { window.open('file:///' + path); return }
  callRuby('open_folder', path)
}

export function openFile(path) {
  if (isMock) { toast('ok', 'Открыть файл: ' + path); return }
  callRuby('open_file', path)
}

export function saveSettings(settings) {
  if (isMock) {
    mockState.settings = JSON.parse(JSON.stringify(settings))
    window.pushState(mockState.payload())
    window.pushResult('settings_saved', {})
    return
  }
  callRubyJson('save_settings', settings)
}

export function resetSettings() {
  if (isMock) {
    mockState.settings = mockState.defaultSettings()
    window.pushState(mockState.payload())
    return
  }
  callRuby('reset_settings')
}

export function openSettingsFile() {
  if (isMock) { toast('ok', mockState.settingsPath); return }
  callRuby('open_settings_file')
}

export function updateFromDev() {
  if (isMock) { toast('ok', 'Обновление из dev-папки (mock)'); return }
  callRuby('update_from_dev')
}

export { state, isMock, toast }
