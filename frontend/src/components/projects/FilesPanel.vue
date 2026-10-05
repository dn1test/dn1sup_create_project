<template>
  <div class="cp-card p-3">
    <div class="flex items-center justify-between mb-2">
      <div class="cp-label">
        Файлы <span class="text-slate-300">({{ files.length }})</span>
      </div>
      <div class="flex gap-1.5">
        <button class="cp-btn-ghost text-xs" @click="openPicker('image')">
          <Image class="w-3.5 h-3.5" /> Изображения…
        </button>
        <button class="cp-btn-ghost text-xs" @click="openPicker('document')">
          <FileText class="w-3.5 h-3.5" /> Документы…
        </button>
      </div>
    </div>

    <!-- скрытые файловые входы; в HtmlDialog (use_file_input) возвращают полные пути -->
    <input
      ref="imageInput"
      type="file"
      multiple
      class="hidden"
      :accept="imageAccept"
      @change="onFilesPicked('image', $event)"
    />
    <input
      ref="docInput"
      type="file"
      multiple
      class="hidden"
      :accept="docAccept"
      @change="onFilesPicked('document', $event)"
    />

    <div class="space-y-1">
      <div
        v-for="file in files"
        :key="file.path"
        class="flex items-center gap-2 py-1.5 px-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/60 group"
      >
        <span
          class="w-6 h-6 rounded flex items-center justify-center shrink-0"
          :class="file.category === 'image'
            ? 'bg-violet-100 dark:bg-violet-950/60 text-violet-500'
            : 'bg-sky-100 dark:bg-sky-950/60 text-sky-500'"
        >
          <Image v-if="file.category === 'image'" class="w-3.5 h-3.5" />
          <FileText v-else class="w-3.5 h-3.5" />
        </span>

        <div class="min-w-0 flex-1">
          <div class="text-xs font-medium truncate" :title="file.path">{{ fileName(file.path) }}</div>
          <div class="text-[10px] text-slate-400">{{ folderName(file.path) }} · {{ file.added_at }}</div>
        </div>

        <input
          :value="file.description || ''"
          type="text"
          class="cp-input !py-1 !px-2 w-40 text-[11px] shrink-0"
          placeholder="описание файла"
          @change="setFileDescription(projectPath, file.path, $event.target.value)"
        />

        <button class="p-1 text-slate-300 hover:text-brand-500 shrink-0" title="Открыть файл" @click="openFile(fullPath(file.path))">
          <ExternalLink class="w-3.5 h-3.5" />
        </button>
        <button class="p-1 text-slate-300 hover:text-red-500 shrink-0" title="Убрать из проекта" @click="removeFile(projectPath, file.path)">
          <X class="w-3.5 h-3.5" />
        </button>
      </div>

      <p v-if="!files.length" class="text-xs text-slate-400 py-3 text-center">
        Файлов пока нет — добавьте изображения и документы.
      </p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { Image, FileText, ExternalLink, X } from 'lucide-vue-next'
import {
  state, addFiles, removeFile, setFileDescription, openFile,
  extractFilePaths, toast
} from '../../composables/useSketchupBridge'

const props = defineProps({
  projectPath: { type: String, required: true },
  files: { type: Array, default: () => [] }
})

const imageInput = ref(null)
const docInput = ref(null)

const exts = computed(() => state.settings?.files)

const imageAccept = computed(() =>
  (exts.value?.images.extensions || []).map(e => '.' + e).join(',')
)
const docAccept = computed(() =>
  (exts.value?.documents.extensions || []).map(e => '.' + e).join(',')
)

function openPicker(category) {
  const input = category === 'image' ? imageInput.value : docInput.value
  if (input) {
    input.value = '' // сброс: повторный выбор того же файла тоже срабатывает
    input.click()
  }
}

function onFilesPicked(category, event) {
  const paths = extractFilePaths(event.target)
  if (!paths.length) {
    toast('err', 'Не удалось получить пути файлов — выберите файлы заново')
    return
  }
  addFiles(props.projectPath, paths, null)
  event.target.value = ''
}

function fileName(path) {
  return String(path || '').split(/[\\/]/).pop()
}

function folderName(path) {
  const parts = String(path || '').split(/[\\/]/)
  return parts.length > 1 ? parts[parts.length - 2] : ''
}

function fullPath(rel) {
  if (!rel) return ''
  return /^([a-zA-Z]:|[\\/])/.test(rel) ? rel : `${props.projectPath}/${rel}`
}
</script>
