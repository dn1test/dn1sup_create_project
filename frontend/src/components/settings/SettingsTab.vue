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
          Время фиксируется в момент добавления проекта; если два проекта добавлены
          в одну секунду, у второго время на секунду больше.
        </p>
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
import { FileUp, FolderOpen, Save, RotateCcw, FileCode } from 'lucide-vue-next'
import {
  state, saveSettings, resetSettings, openSettingsFile, pickFolder, pickTemplate,
  onResult
} from '../../composables/useSketchupBridge'

const draft = ref(null)

function refresh() {
  if (!state.settings) return
  draft.value = JSON.parse(JSON.stringify(state.settings))
}

watch(() => state.settings, refresh, { immediate: true, deep: false })

const dirty = computed(() =>
  draft.value && state.settings ? JSON.stringify(draft.value) !== JSON.stringify(state.settings) : false
)

async function chooseRoot() {
  const path = await pickFolder('root')
  if (path && draft.value) draft.value.defaults.projects_root = path
}

// Ruby копирует шаблон в data/ и сохраняет настройки — отражаем путь в черновике,
// не затирая несохранённые правки других полей
let offTemplate = null
onMounted(() => {
  offTemplate = onResult('template_added', (payload) => {
    if (draft.value && payload.kind && payload.path) {
      draft.value.structure.templates[payload.kind] = `data/template.${payload.kind}`
    }
  })
})
onUnmounted(() => {
  if (offTemplate) offTemplate()
})

function save() {
  if (draft.value) saveSettings(JSON.parse(JSON.stringify(draft.value)))
}

function reset() {
  resetSettings()
}
</script>
