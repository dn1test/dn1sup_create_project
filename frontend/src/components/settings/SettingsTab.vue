<template>
  <div class="space-y-3 max-w-3xl mx-auto pb-4">
    <p v-if="!draft" class="text-sm text-slate-400 text-center py-10">Настройки ещё не загружены…</p>

    <template v-else>
      <!-- Директория проектов -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Директория проектов</div>
        <p class="text-[10px] text-slate-400">
          Папка, в которой создаются все проекты. Структура внутри собирается
          из шаблонов ниже: корень → папка заказа (1 уровень) → папки проектов (2 уровень).
        </p>
        <div class="flex gap-2">
          <input
            v-model="draft.defaults.projects_root"
            type="text"
            class="cp-input font-mono text-xs"
            placeholder="U:/desktop/su_projects"
          />
          <button class="cp-btn-ghost shrink-0 text-xs" @click="chooseRoot">
            <FolderOpen class="w-4 h-4" /> Выбрать…
          </button>
        </div>
      </section>

      <!-- Блок 1: бытовой проект -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Папки бытового проекта</div>
        <p class="text-[10px] text-slate-400">Плейсхолдеры: <code class="font-mono">{customer} {company} {address} {phone} {email} {place} {product} {articul}</code></p>
        <label class="block">
          <span class="block mb-0.5 text-[11px] text-slate-400">Папка заказа, 1 уровень</span>
          <input v-model="draft.structure.folders.household.order" type="text" class="cp-input font-mono text-xs" />
          <span class="block mt-0.5 text-[10px] text-slate-400">например: <code class="font-mono">{customer} ~ {address}</code></span>
        </label>
        <label class="block">
          <span class="block mb-0.5 text-[11px] text-slate-400">Папки проектов, 2 уровень</span>
          <input v-model="draft.structure.folders.household.project" type="text" class="cp-input font-mono text-xs" />
          <span class="block mt-0.5 text-[10px] text-slate-400">например: <code class="font-mono">{place}</code></span>
        </label>
      </section>

      <!-- Блок 2: коммерческий проект -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Папки коммерческого проекта</div>
        <label class="block">
          <span class="block mb-0.5 text-[11px] text-slate-400">Папка заказа, 1 уровень</span>
          <input v-model="draft.structure.folders.commercial.order" type="text" class="cp-input font-mono text-xs" />
          <span class="block mt-0.5 text-[10px] text-slate-400">например: <code class="font-mono">{customer} ~ {company} ~ {address}</code></span>
        </label>
        <label class="block">
          <span class="block mb-0.5 text-[11px] text-slate-400">Папки проектов, 2 уровень</span>
          <input v-model="draft.structure.folders.commercial.project" type="text" class="cp-input font-mono text-xs" />
          <span class="block mt-0.5 text-[10px] text-slate-400">например: <code class="font-mono">{place} ~ {product}</code></span>
        </label>
      </section>

      <!-- Блок 3: шаблоны -->
      <section class="cp-card p-3 space-y-3">
        <div class="cp-label">Шаблоны файлов проекта</div>
        <p class="text-[10px] text-slate-400">
          Шаблон копируется в папку расширения и кладётся в каждый проект под новым именем.
          Имена файлов поддерживают те же плейсхолдеры.
        </p>

        <div class="rounded-lg border border-slate-200 dark:border-slate-800 p-2.5 space-y-2">
          <div class="flex items-center gap-2">
            <span class="text-xs font-semibold text-slate-500 dark:text-slate-400 w-20 shrink-0">template.skp</span>
            <span class="text-[10px] font-mono text-slate-400 truncate flex-1" :title="draft.structure.templates.skp">
              {{ draft.structure.templates.skp }}
            </span>
            <button class="cp-btn-ghost !py-1 shrink-0 text-xs" @click="pickTemplate('skp')">
              <FileUp class="w-3.5 h-3.5" /> Добавить шаблон
            </button>
            <input ref="skpInput" type="file" accept=".skp" class="hidden" @change="onTemplatePicked($event, 'skp')" />
          </div>
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Имя .skp в папке проекта</span>
            <input v-model="draft.naming.skp_file" type="text" class="cp-input font-mono text-xs" />
            <span class="block mt-0.5 text-[10px] text-slate-400">например: <code class="font-mono">{place} ~ {product}.skp</code></span>
          </label>
        </div>

        <div class="rounded-lg border border-slate-200 dark:border-slate-800 p-2.5 space-y-2">
          <div class="flex items-center gap-2">
            <span class="text-xs font-semibold text-slate-500 dark:text-slate-400 w-20 shrink-0">template.pur</span>
            <span class="text-[10px] font-mono text-slate-400 truncate flex-1" :title="draft.structure.templates.pur">
              {{ draft.structure.templates.pur }}
            </span>
            <button class="cp-btn-ghost !py-1 shrink-0 text-xs" @click="pickTemplate('pur')">
              <FileUp class="w-3.5 h-3.5" /> Добавить шаблон
            </button>
            <input ref="purInput" type="file" accept=".pur" class="hidden" @change="onTemplatePicked($event, 'pur')" />
          </div>
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Имя .pur в папке проекта</span>
            <input v-model="draft.naming.pur_file" type="text" class="cp-input font-mono text-xs" />
            <span class="block mt-0.5 text-[10px] text-slate-400">например: <code class="font-mono">{articul}.pur</code></span>
          </label>
        </div>

        <label class="block">
          <span class="block mb-0.5 text-[11px] text-slate-400">Имя YAML-карточки</span>
          <input v-model="draft.naming.yaml_file" type="text" class="cp-input font-mono text-xs" />
        </label>
      </section>

      <!-- Артикулы -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Артикулы</div>
        <div class="grid grid-cols-3 gap-2">
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Коммерческий префикс</span>
            <input v-model="draft.articul.commercial_prefix" type="text" class="cp-input font-mono" />
          </label>
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Бытовой префикс</span>
            <input v-model="draft.articul.household_prefix" type="text" class="cp-input font-mono" />
          </label>
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Формат времени</span>
            <input v-model="draft.articul.timestamp_format" type="text" class="cp-input font-mono" />
          </label>
        </div>
        <p class="text-[10px] text-slate-400">
          Артикул = префикс + время ({{ draft.articul.timestamp_format }}).
          Несколько проектов за раз создаются с шагом в 1 секунду — последняя цифра артикула отличается.
        </p>
      </section>

      <!-- Списки -->
      <section class="cp-card p-3 space-y-3">
        <div class="cp-label">Списки выбора</div>

        <div>
          <div class="text-[11px] text-slate-500 dark:text-slate-400 mb-1">Коммерческие продукты</div>
          <ChipsEditor v-model="draft.lists.commercial_products" />
        </div>

        <div>
          <div class="text-[11px] text-slate-500 dark:text-slate-400 mb-1">Места (бытовой режим)</div>
          <ChipsEditor v-model="draft.lists.places" />
        </div>

        <div>
          <div class="text-[11px] text-slate-500 dark:text-slate-400 mb-1">Мебель для нестандартного места</div>
          <ChipsEditor v-model="draft.lists.other_products" />
        </div>

        <div>
          <div class="flex items-center justify-between mb-1">
            <div class="text-[11px] text-slate-500 dark:text-slate-400">Мебель по местам</div>
            <div class="flex gap-1">
              <select v-model="selectedPlace" class="cp-input !py-1 !w-auto text-xs">
                <option v-for="place in placeKeys" :key="place" :value="place">{{ place }}</option>
              </select>
              <button class="cp-btn-ghost !py-1 text-xs" @click="addPlaceGroup">
                <Plus class="w-3 h-3" /> место
              </button>
              <button
                v-if="selectedPlace"
                class="cp-btn-danger !py-1 text-xs"
                @click="removePlaceGroup(selectedPlace)"
              >
                <Trash2 class="w-3 h-3" />
              </button>
            </div>
          </div>
          <div v-if="selectedPlace" class="rounded-lg border border-slate-200 dark:border-slate-800 p-2">
            <div class="text-[10px] text-slate-400 mb-1">Мебель для «{{ selectedPlace }}»</div>
            <ChipsEditor
              :model-value="draft.lists.products_by_place[selectedPlace] || []"
              @update:model-value="draft.lists.products_by_place[selectedPlace] = $event"
            />
          </div>
        </div>
      </section>

      <!-- Файлы -->
      <section class="cp-card p-3 space-y-3">
        <div class="cp-label">Файлы проекта</div>
        <p class="text-[10px] text-slate-400">
          Папки по умолчанию для файлов, добавляемых кнопкой «Добавить файлы»
          (вкладка «Проекты»), и списки расширений для определения типа.
        </p>
        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-1.5">
            <label class="block">
              <span class="block mb-0.5 text-[11px] text-slate-400">Папка изображений</span>
              <input v-model="draft.files.images.folder" type="text" class="cp-input text-xs" />
            </label>
            <ChipsEditor v-model="draft.files.images.extensions" placeholder="расширения изображений" />
          </div>
          <div class="space-y-1.5">
            <label class="block">
              <span class="block mb-0.5 text-[11px] text-slate-400">Папка документов</span>
              <input v-model="draft.files.documents.folder" type="text" class="cp-input text-xs" />
            </label>
            <ChipsEditor v-model="draft.files.documents.extensions" placeholder="расширения документов" />
          </div>
        </div>
      </section>

      <!-- Действия -->
      <div class="flex gap-2">
        <button class="cp-btn-primary flex-1" :disabled="!dirty" @click="save">
          <Save class="w-4 h-4" /> Сохранить настройки
        </button>
        <button class="cp-btn-ghost" @click="reset">
          <RotateCcw class="w-4 h-4" /> Сбросить
        </button>
        <button class="cp-btn-ghost" title="Открыть settings.yaml" @click="openSettingsFile">
          <FileCode class="w-4 h-4" />
        </button>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { FileUp, FolderOpen, Plus, Trash2, Save, RotateCcw, FileCode } from 'lucide-vue-next'
import ChipsEditor from './ChipsEditor.vue'
import {
  state, saveSettings, resetSettings, openSettingsFile, pickFolder, addTemplate,
  extractFilePaths, onResult
} from '../../composables/useSketchupBridge'

const draft = ref(null)
const selectedPlace = ref('')
const placeKeys = ref([])
const skpInput = ref(null)
const purInput = ref(null)

function refresh() {
  if (!state.settings) return
  draft.value = JSON.parse(JSON.stringify(state.settings))
  placeKeys.value = Object.keys(draft.value.lists?.products_by_place || {})
  if (!selectedPlace.value || !placeKeys.value.includes(selectedPlace.value)) {
    selectedPlace.value = placeKeys.value[0] || ''
  }
}

watch(() => state.settings, refresh, { immediate: true, deep: false })

const dirty = computed(() =>
  draft.value && state.settings ? JSON.stringify(draft.value) !== JSON.stringify(state.settings) : false
)

async function chooseRoot() {
  const path = await pickFolder('root')
  if (path && draft.value) draft.value.defaults.projects_root = path
}

function pickTemplate(kind) {
  const input = kind === 'skp' ? skpInput.value : purInput.value
  input && input.click()
}

function onTemplatePicked(event, kind) {
  const paths = extractFilePaths(event.target)
  if (paths[0]) addTemplate(kind, paths[0])
  event.target.value = ''
}

// Ruby копирует шаблон в data/ и сохраняет настройки — отражаем путь в черновике,
// не затирая несохранённые правки других полей
let offTemplate = null
onMounted(() => {
  offTemplate = onResult('template_added', (payload) => {
    if (draft.value && payload.kind) {
      draft.value.structure.templates[payload.kind] = `data/template.${payload.kind}`
    }
  })
})
onUnmounted(() => {
  if (offTemplate) offTemplate()
})

function addPlaceGroup() {
  const name = window.prompt('Название места:', '')
  if (!name || !name.trim()) return
  const key = name.trim()
  if (!draft.value.lists.products_by_place[key]) {
    draft.value.lists.products_by_place[key] = [...draft.value.lists.other_products]
    placeKeys.value = Object.keys(draft.value.lists.products_by_place)
  }
  selectedPlace.value = key
}

function removePlaceGroup(key) {
  delete draft.value.lists.products_by_place[key]
  placeKeys.value = Object.keys(draft.value.lists.products_by_place)
  selectedPlace.value = placeKeys.value[0] || ''
}

function save() {
  if (draft.value) saveSettings(JSON.parse(JSON.stringify(draft.value)))
}

function reset() {
  resetSettings()
}
</script>
