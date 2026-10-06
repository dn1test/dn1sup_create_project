<template>
  <div class="h-full flex gap-3">
    <!-- Список проектов -->
    <aside class="w-56 shrink-0 flex flex-col gap-2">
      <button class="cp-btn-ghost text-xs w-full" @click="registerExisting">
        <FolderInput class="w-3.5 h-3.5" /> Добавить существующий
      </button>

      <div class="flex-1 overflow-y-auto space-y-1 pr-0.5">
        <button
          v-for="project in state.projects"
          :key="project.path"
          class="w-full text-left px-2.5 py-2 rounded-lg border transition-colors"
          :class="selectedPath === project.path
            ? 'border-brand-500 bg-brand-50 dark:bg-brand-950/40'
            : 'border-slate-200 dark:border-slate-800 hover:border-brand-300 bg-white dark:bg-slate-900/60'"
          @click="select(project.path)"
        >
          <div class="text-[11px] font-mono text-brand-600 dark:text-brand-300 truncate">{{ project.articul || 'без артикула' }}</div>
          <div class="text-xs font-medium truncate">{{ project.name }}</div>
          <div class="flex items-center gap-1.5 mt-0.5 text-[10px] text-slate-400">
            <span class="truncate">{{ project.type }}</span>
            <span v-if="project.files_count" class="flex items-center gap-0.5 shrink-0">
              <Paperclip class="w-2.5 h-2.5" /> {{ project.files_count }}
            </span>
          </div>
        </button>

        <div v-if="!state.projects.length" class="text-xs text-slate-400 px-1 py-6 text-center">
          Нет зарегистрированных проектов.<br />Создайте первый на вкладке «Создать»
          или добавьте существующую папку.
        </div>
      </div>
    </aside>

    <!-- Карточка проекта -->
    <section class="flex-1 min-w-0 overflow-y-auto">
      <template v-if="detail">
        <!-- Заголовок -->
        <div class="cp-card p-3 mb-3">
          <div class="flex items-start justify-between gap-2">
            <div class="min-w-0">
              <h2 class="text-sm font-semibold break-words">{{ detail.card.project_name }}</h2>
              <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5 mt-1 text-[11px] text-slate-400">
                <span v-if="detail.card.articul" class="font-mono text-brand-600 dark:text-brand-300">{{ detail.card.articul }}</span>
                <span v-if="detail.card.project_type">{{ detail.card.project_type }}</span>
                <span v-if="detail.card.place">{{ detail.card.place }}</span>
                <span v-if="detail.card.product">{{ detail.card.product }}</span>
                <span v-if="detail.card.phone" class="flex items-center gap-0.5">
                  <Phone class="w-2.5 h-2.5" /> {{ detail.card.phone }}
                </span>
                <span v-if="detail.card.email" class="flex items-center gap-0.5">
                  <Mail class="w-2.5 h-2.5" /> {{ detail.card.email }}
                </span>
              </div>
            </div>
            <div class="flex shrink-0 gap-1">
              <button class="cp-btn-ghost text-xs" title="Открыть папку проекта" @click="openFolder(detail.card.path)">
                <FolderOpen class="w-3.5 h-3.5" /> Папка
              </button>
              <button
                class="cp-btn-danger text-xs"
                title="Убрать проект из списка (папка и файлы не удаляются)"
                @click="unregister(detail.card.path)"
              >
                <FolderMinus class="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </div>

        <!-- Описание -->
        <div class="cp-card p-3 mb-3">
          <div class="cp-label mb-2">Описание</div>
          <textarea
            v-model="descriptionDraft"
            rows="3"
            class="cp-input resize-y text-sm"
            placeholder="Особенности заказа, пожелания заказчика, сроки…"
          ></textarea>
          <div class="flex justify-end mt-1.5">
            <button
              class="cp-btn-primary text-xs"
              :disabled="descriptionDraft === (detail.card.description || '')"
              @click="saveDescription(detail.card.path, descriptionDraft)"
            >
              <Save class="w-3.5 h-3.5" /> Сохранить
            </button>
          </div>
        </div>

        <!-- Файлы -->
        <FilesPanel :project-path="detail.card.path" :files="detail.card.files || []" class="mb-3" />

        <!-- Подпапки -->
        <div class="cp-card p-3 mb-3">
          <div class="cp-label mb-2">Подпапки</div>
          <div v-if="detail.card.subfolders && detail.card.subfolders.length" class="flex flex-wrap gap-1.5 mb-2.5">
            <span
              v-for="sub in detail.card.subfolders"
              :key="sub"
              class="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-[11px] text-slate-600 dark:text-slate-300 font-mono"
            >
              <Folder class="w-3 h-3 text-slate-400 shrink-0" />
              {{ sub }}
            </span>
          </div>
          <div class="flex gap-1.5">
            <input
              v-model="subfolderDraft"
              type="text"
              class="cp-input"
              placeholder="имя новой папки внутри проекта, например _тендер"
              @keydown.enter.prevent="addSubfolder"
            />
            <button class="cp-btn-ghost shrink-0 text-xs" @click="addSubfolder">
              <FolderPlus class="w-3.5 h-3.5" /> Создать
            </button>
          </div>
        </div>

        <!-- История -->
        <div class="cp-card p-3 mb-3">
          <div class="cp-label mb-2">История</div>
          <div class="space-y-1.5">
            <div
              v-for="(entry, index) in historyReversed"
              :key="index"
              class="flex items-start gap-2 text-xs"
            >
              <span class="text-slate-400 font-mono text-[10px] shrink-0 pt-0.5">{{ entry.data }}</span>
              <span
                class="shrink-0 px-1.5 py-px rounded text-[10px] font-semibold bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"
              >{{ entry.status }}</span>
              <span class="text-slate-600 dark:text-slate-300">{{ entry.text }}</span>
            </div>
            <p v-if="!historyReversed.length" class="text-xs text-slate-400">История пуста.</p>
          </div>
        </div>
      </template>

      <div v-else class="h-full flex items-center justify-center text-sm text-slate-400">
        {{ state.projects.length ? 'Выберите проект слева' : '' }}
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed, ref, watch, onMounted, onUnmounted } from 'vue'
import { Folder, FolderInput, FolderOpen, FolderMinus, FolderPlus, Mail, Paperclip, Phone, Save } from 'lucide-vue-next'
import FilesPanel from './FilesPanel.vue'
import {
  state, openProject, registerExisting, saveDescription, openFolder, createSubfolder,
  unregisterProject, onResult
} from '../../composables/useSketchupBridge'

const selectedPath = ref('')

const detail = computed(() =>
  state.selected && state.selected.card && state.selected.card.path === selectedPath.value
    ? state.selected
    : null
)

const descriptionDraft = ref('')
const subfolderDraft = ref('')

function addSubfolder() {
  const name = subfolderDraft.value.trim()
  if (!name || !detail.value) return
  createSubfolder(detail.value.card.path, name)
  subfolderDraft.value = ''
}

const historyReversed = computed(() =>
  detail.value ? [...(detail.value.history?.project_history || [])].reverse() : []
)

function select(path) {
  selectedPath.value = path
  state.selected = { path, card: null, history: null } // локальный «loading»
  openProject(path)
}

function unregister(path) {
  unregisterProject(path)
  selectedPath.value = ''
  state.selected = null
}

// Ruby отвечает pushResult('project', {card, history}) — заполняем панель
let offProject = null
onMounted(() => {
  offProject = onResult('project', (payload) => {
    if (payload && payload.card) state.selected = payload
  })
})
onUnmounted(() => {
  if (offProject) offProject()
})

watch(
  () => state.selected,
  (sel) => {
    if (sel && sel.card) descriptionDraft.value = sel.card.description || ''
  },
  { deep: false }
)
</script>
