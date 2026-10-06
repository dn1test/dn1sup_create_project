<template>
  <div class="rounded-lg border border-slate-200 dark:border-slate-800 p-2.5 space-y-2">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2 min-w-0">
        <div
          class="text-xs font-semibold text-slate-500 dark:text-slate-400 truncate"
          :title="projectTitle"
        >
          {{ projectTitle }}
        </div>
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
          @input="project.place = $event.target.value"
        />
      </label>

      <div>
        <span class="block mb-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400">
          Продукт / Название мебели<span class="text-brand-500"> *</span>
        </span>
        <input
          v-model="project.product"
          type="text"
          class="cp-input"
          :placeholder="productPlaceholder"
        />
      </div>
    </div>

    <!-- Файлы проекта: группы «имя папки → файлы» -->
    <div class="space-y-1.5 pt-0.5">
      <div class="flex items-center justify-between">
        <span class="text-[11px] font-medium text-slate-500 dark:text-slate-400">
          Файлы
          <span v-if="filesTotal" class="text-slate-400 font-normal">({{ filesTotal }})</span>
        </span>
        <div class="flex gap-1.5">
          <button class="cp-btn-ghost !py-1 text-xs" :disabled="picking" @click="pickFiles">
            <Paperclip class="w-3.5 h-3.5" /> {{ picking ? 'Выбор…' : 'Добавить файлы' }}
          </button>
          <button class="cp-btn-ghost !py-1 text-xs" :disabled="picking" @click="pickFilesFromFolder">
            <FolderOpen class="w-3.5 h-3.5" /> Папку
          </button>
        </div>
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
        Добавьте файлы по одному («Добавить файлы») или целую папку («Папку») —
        каждая группа попадёт в свою подпапку внутри папки проекта.
      </p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { Box, File, FileText, FolderOpen, Image, Paperclip, Trash2, X } from 'lucide-vue-next'
import { pickFiles as pickFilesDialog, pickFolderFiles } from '../../composables/useSketchupBridge'

const props = defineProps({
  project: { type: Object, required: true },
  index: { type: Number, required: true },
  type: { type: String, required: true },
  settings: { type: Object, default: null },
  canRemove: { type: Boolean, default: true }
})

defineEmits(['remove'])

const picking = ref(false)
let groupSeq = 0

const productPlaceholder = computed(() =>
  props.type === 'commercial'
    ? 'Торговая мебель, остров, павильон…'
    : 'Название мебели, например Шкаф…'
)

// заголовок строки: место и продукт, пока не заполнены — «Проект N»
const projectTitle = computed(() => {
  const parts = [props.project.place.trim(), props.project.product.trim()].filter(Boolean)
  return parts.length ? parts.join(' ~ ') : `Проект ${props.index + 1}`
})

const filesTotal = computed(() =>
  props.project.groups.reduce((sum, g) => sum + g.files.length, 0)
)

const IMAGE_EXTS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tif', 'tiff']

// CEF не отдаёт путь из <input type="file"> — файлы выбираются нативными
// диалогами Windows на стороне Ruby (полные пути приходят в результате).

function fileUrl(path) {
  return encodeURI('file:///' + String(path).replace(/\\/g, '/')).replace(/#/g, '%23')
}

function entryForPath(path) {
  const name = String(path).split(/[\\/]/).pop() || String(path)
  const ext = (name.split('.').pop() || '').toLowerCase()
  const isImage = IMAGE_EXTS.includes(ext)
  return { name, path, ext, isImage, preview: isImage ? fileUrl(path) : '' }
}

function defaultFolderFor(entries) {
  const images = entries.filter(e => e.isImage).length
  return images * 2 >= entries.length
    ? (props.settings?.files?.images?.folder || '_изображения')
    : (props.settings?.files?.documents?.folder || '_документы')
}

/** Выбрать несколько файлов нативным диалогом — дописать в группу своего типа. */
async function pickFiles() {
  if (picking.value) return
  picking.value = true
  try {
    const paths = await pickFilesDialog(`row-${props.project._id}-${Date.now()}`)
    if (!paths.length) return
    const entries = paths.map(entryForPath)
    const autoName = defaultFolderFor(entries)
    let group = [...props.project.groups].reverse().find(g => g.folder === autoName)
    if (!group) {
      group = { id: ++groupSeq + '-' + Date.now(), folder: autoName, files: [] }
      props.project.groups.push(group)
    }
    group.files.push(...entries)
  } finally {
    picking.value = false
  }
}

/** Выбрать папку нативным диалогом — все её файлы становятся новой группой. */
async function pickFilesFromFolder() {
  if (picking.value) return
  picking.value = true
  try {
    const res = await pickFolderFiles(`row-${props.project._id}-folder-${Date.now()}`)
    if (!res || !res.paths || !res.paths.length) return
    const folder = (res.folder_name || '').trim() || '_файлы'
    props.project.groups.push({ id: ++groupSeq + '-' + Date.now(), folder, files: res.paths.map(entryForPath) })
  } finally {
    picking.value = false
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
