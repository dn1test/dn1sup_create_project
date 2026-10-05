<template>
  <div class="space-y-3 max-w-3xl mx-auto pb-4">
    <p v-if="!draft" class="text-sm text-slate-400 text-center py-10">Настройки ещё не загружены…</p>

    <template v-else>
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
        <p class="text-[10px] text-slate-400">Артикул = префикс + время ({{ draft.articul.timestamp_format }}) + номер 01, 02… (для бытовых)</p>
      </section>

      <!-- Подпапки и шаблоны -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Подпапки каждого проекта</div>
        <ChipsEditor v-model="draft.structure.subfolders" placeholder="имя подпапки, Enter — добавить" />
        <div class="grid grid-cols-2 gap-2 pt-1">
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Шаблон .skp (от папки расширения)</span>
            <input v-model="draft.structure.templates.skp" type="text" class="cp-input font-mono text-xs" />
          </label>
          <label class="block">
            <span class="block mb-0.5 text-[11px] text-slate-400">Шаблон .pur</span>
            <input v-model="draft.structure.templates.pur" type="text" class="cp-input font-mono text-xs" />
          </label>
        </div>
      </section>

      <!-- Именование -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Шаблоны имён</div>
        <p class="text-[10px] text-slate-400">
          Плейсхолдеры: <code class="font-mono">{articul} {customer} {company} {address} {place} {product} {timestamp}</code>.
          Пустые сегменты «~» и запятые убираются автоматически.
        </p>
        <label
          v-for="(title, key) in namingFields"
          :key="key"
          class="block"
        >
          <span class="block mb-0.5 text-[11px] text-slate-400">{{ title }}</span>
          <input v-model="draft.naming[key]" type="text" class="cp-input font-mono text-xs" />
        </label>
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
        <label class="block">
          <span class="block mb-0.5 text-[11px] text-slate-400">Корневая папка проектов по умолчанию</span>
          <input v-model="draft.defaults.projects_root" type="text" class="cp-input font-mono text-xs" />
        </label>
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
import { ref, computed, watch } from 'vue'
import { Plus, Trash2, Save, RotateCcw, FileCode } from 'lucide-vue-next'
import ChipsEditor from './ChipsEditor.vue'
import { state, saveSettings, resetSettings, openSettingsFile } from '../../composables/useSketchupBridge'

const namingFields = {
  commercial_folder: 'Папка коммерческого проекта',
  household_order_folder: 'Папка бытового заказа',
  household_project_folder: 'Папка бытового проекта',
  commercial_file: 'Имя файлов .skp/.pur (коммерческий)',
  household_skp_file: 'Имя .skp (бытовой)',
  pur_file: 'Имя .pur (бытовой)',
  yaml_file: 'Имя YAML-карточки'
}

const draft = ref(null)
const selectedPlace = ref('')

function refresh() {
  if (!state.settings) return
  draft.value = JSON.parse(JSON.stringify(state.settings))
  placeKeys.value = Object.keys(draft.value.lists.products_by_place || {})
  if (!selectedPlace.value || !placeKeys.value.includes(selectedPlace.value)) {
    selectedPlace.value = placeKeys.value[0] || ''
  }
}

watch(() => state.settings, refresh, { immediate: true, deep: false })

const placeKeys = ref([])

const dirty = computed(() =>
  draft.value && state.settings ? JSON.stringify(draft.value) !== JSON.stringify(state.settings) : false
)

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
