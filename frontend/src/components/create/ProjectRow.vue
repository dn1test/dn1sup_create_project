<template>
  <div class="rounded-lg border border-slate-200 dark:border-slate-800 p-2.5 space-y-2">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2 min-w-0">
        <div class="text-xs font-semibold text-slate-500 dark:text-slate-400 shrink-0">
          Проект {{ index + 1 }}
        </div>
        <span
          v-if="articulPreview"
          class="px-1.5 py-px rounded bg-brand-50 dark:bg-brand-950/50 border border-brand-200 dark:border-brand-900
                 text-[10px] font-mono font-semibold text-brand-600 dark:text-brand-300 truncate"
          :title="`Артикул проекта №${index + 1}`"
        >{{ articulPreview }}</span>
      </div>
      <button
        v-if="canRemove"
        class="cp-btn-danger !py-1 !px-1.5 text-xs"
        title="Удалить проект"
        @click="$emit('remove')"
      >
        <Trash2 class="w-3.5 h-3.5" />
      </button>
    </div>

    <div class="grid gap-2 grid-cols-1 sm:grid-cols-2">
      <label class="block">
        <span class="block mb-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400">
          {{ type === 'commercial' ? 'Место (ТЦ / место размещения)' : 'Место / Комната' }}<span class="text-brand-500"> *</span>
        </span>
        <input
          :value="project.place"
          type="text"
          class="cp-input"
          :placeholder="type === 'commercial' ? 'ТЦ, павильон, улица…' : 'Кухня, гостиная…'"
          :list="placesListId"
          @input="project.place = $event.target.value"
        />
        <datalist v-if="placesOptions.length" :id="placesListId">
          <option v-for="option in placesOptions" :key="option" :value="option" />
        </datalist>
      </label>

      <div>
        <span class="block mb-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400">
          Продукт / Название мебели<span class="text-brand-500"> *</span>
        </span>
        <div class="flex gap-1.5">
          <input
            v-model="project.product"
            type="text"
            class="cp-input"
            :placeholder="productPlaceholder"
            :list="productsListId"
          />
          <select
            v-if="suggestions.length"
            class="cp-input !w-auto shrink-0 text-xs"
            value=""
            @change="project.product = $event.target.value; $event.target.value = ''"
          >
            <option value="" disabled>из списка…</option>
            <option v-for="option in suggestions" :key="option" :value="option">{{ option }}</option>
          </select>
        </div>
        <datalist v-if="suggestions.length" :id="productsListId">
          <option v-for="option in suggestions" :key="option" :value="option" />
        </datalist>
      </div>
    </div>

    <!-- Файлы проекта: группы «имя папки → файлы» -->
    <div class="space-y-1.5 pt-0.5">
      <div class="flex items-center justify-between">
        <span class="text-[11px] font-medium text-slate-500 dark:text-slate-400">
          Файлы
          <span v-if="filesTotal" class="text-slate-400 font-normal">({{ filesTotal }})</span>
        </span>
        <button class="cp-btn-ghost !py-1 text-xs" @click="pickFiles">
          <Paperclip class="w-3.5 h-3.5" /> Добавить файлы
        </button>
        <input ref="fileInput" type="file" multiple class="hidden" @change="onFilesPicked" />
      </div>

      <div
        v-for="(group, gi) in project.groups"
        :key="group.id"
        class="rounded-lg border border-slate-200 dark:border-slate-800 p-2 space-y-1.5"
      >
        <div class="flex items-center gap-1.5">
          <FolderOpen class="w-3.5 h-3.5 text-slate-400 shrink-0" />
          <input
            v-model="group.folder"
            type="text"
            class="cp-input !py-1 text-xs font-mono"
            :class="{ '!border-red-400': !group.folder.trim() }"
            placeholder="имя папки внутри проекта, например «Фото ТЦ»"
            title="Папка будет создана внутри папки проекта"
          />
          <button
            class="cp-btn-danger !py-1 !px-1.5 text-xs shrink-0"
            title="Удалить папку со всеми файлами"
            @click="removeGroup(gi)"
          >
            <Trash2 class="w-3.5 h-3.5" />
          </button>
        </div>

        <div class="flex flex-wrap gap-1.5">
          <div
            v-for="(file, fi) in group.files"
            :key="file.path + fi"
            class="relative w-[76px] rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-1"
          >
            <img
              v-if="file.preview"
              :src="file.preview"
              class="w-full h-11 object-cover rounded"
              alt=""
            />
            <div
              v-else
              class="w-full h-11 rounded bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-400"
            >
              <component :is="fileIcon(file.ext)" class="w-5 h-5" />
            </div>
            <div class="text-[9px] leading-tight mt-0.5 truncate text-slate-600 dark:text-slate-300" :title="file.name">
              {{ file.name }}
            </div>
            <button
              class="absolute -top-1.5 -right-1.5 w-4 h-4 rounded-full bg-slate-200 dark:bg-slate-700
                     flex items-center justify-center text-slate-500 hover:bg-red-500 hover:text-white transition-colors"
              title="Убрать файл"
              @click="removeFile(gi, fi)"
            >
              <X class="w-2.5 h-2.5" />
            </button>
          </div>
        </div>
      </div>

      <p v-if="!project.groups.length" class="text-[10px] text-slate-400 dark:text-slate-500 leading-relaxed">
        Добавьте файлы (фото, замеры, референсы) — каждая порция попадёт в свою папку
        внутри папки этого проекта.
      </p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { Box, File, FileText, FolderOpen, Image, Paperclip, Trash2, X } from 'lucide-vue-next'
import { extractFilePaths } from '../../composables/useSketchupBridge'
import { buildArticul, makeTimestamp, timestampWithOffset } from '../../utils/naming'

const props = defineProps({
  project: { type: Object, required: true },
  index: { type: Number, required: true },
  type: { type: String, required: true },
  settings: { type: Object, default: null },
  canRemove: { type: Boolean, default: true },
  baseTime: { type: Date, required: true }
})

defineEmits(['remove'])

const fileInput = ref(null)
const placesListId = `places-${Math.random().toString(36).slice(2, 9)}`
const productsListId = `products-${Math.random().toString(36).slice(2, 9)}`
let groupSeq = 0

const placesOptions = computed(() =>
  props.type === 'household' ? (props.settings?.lists.places || []) : []
)

const suggestions = computed(() => {
  const s = props.settings
  if (!s) return []
  if (props.type === 'commercial') return s.lists.commercial_products || []
  const byPlace = s.lists.products_by_place || {}
  return byPlace[props.project.place] || s.lists.other_products || []
})

const productPlaceholder = computed(() =>
  props.type === 'commercial'
    ? 'Торговая мебель, остров, павильон…'
    : 'Название мебели, например Шкаф…'
)

// артикул блока: метка времени + сдвиг на номер проекта (шаг 1 секунда)
const articulPreview = computed(() => {
  if (!props.settings) return ''
  return buildArticul(props.settings, props.type, timestampWithOffset(props.baseTime, props.index))
})

const filesTotal = computed(() =>
  props.project.groups.reduce((sum, g) => sum + g.files.length, 0)
)

function pickFiles() {
  fileInput.value && fileInput.value.click()
}

const IMAGE_EXTS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tif', 'tiff']

function onFilesPicked(event) {
  const files = Array.from((event.target && event.target.files) || [])
  if (!files.length) return

  const entries = files.map((file) => {
    const ext = (file.name.split('.').pop() || '').toLowerCase()
    const isImage = IMAGE_EXTS.includes(ext)
    const entry = {
      name: file.name,
      path: file.path || file.fullPath || file.name,
      ext,
      isImage,
      preview: ''
    }
    if (isImage) readPreview(file, entry)
    return entry
  })

  // папка группы — по преобладающему типу файлов (_изображения / _документы из настроек)
  const images = entries.filter(e => e.isImage).length
  const folder = images * 2 >= entries.length
    ? (props.settings?.files?.images?.folder || '_изображения')
    : (props.settings?.files?.documents?.folder || '_документы')

  props.project.groups.push({ id: ++groupSeq + '-' + Date.now(), folder, files: entries })
  event.target.value = '' // один и тот же файл можно выбрать повторно
}

function readPreview(file, entry) {
  try {
    const reader = new FileReader()
    reader.onload = () => { entry.preview = reader.result }
    reader.onerror = () => { entry.preview = '' }
    reader.readAsDataURL(file)
  } catch (e) {
    entry.preview = ''
  }
}

function fileIcon(ext) {
  if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'rtf', 'odt'].includes(ext)) return FileText
  if (['skp', 'pur'].includes(ext)) return Box
  if (IMAGE_EXTS.includes(ext)) return Image
  return File
}

function removeGroup(index) {
  props.project.groups.splice(index, 1)
}

function removeFile(groupIndex, fileIndex) {
  props.project.groups[groupIndex].files.splice(fileIndex, 1)
  if (!props.project.groups[groupIndex].files.length) {
    props.project.groups.splice(groupIndex, 1)
  }
}
</script>
