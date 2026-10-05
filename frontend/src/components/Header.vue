<template>
  <header
    class="px-3.5 py-2.5 flex items-center justify-between border-b border-slate-200/70 dark:border-slate-800/70 shrink-0"
  >
    <div class="flex items-center gap-2 min-w-0">
      <div class="w-7 h-7 rounded-lg bg-brand-500 flex items-center justify-center shrink-0">
        <FolderPlus class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0">
        <h1 class="text-sm font-semibold leading-tight truncate">Create Project</h1>
        <p class="text-[10px] text-slate-400 dark:text-slate-500 leading-tight">
          структура мебельных проектов
        </p>
      </div>
      <span
        class="ml-1 px-1.5 py-0.5 rounded bg-slate-200/70 dark:bg-slate-800 text-[10px] font-mono text-slate-500 dark:text-slate-400"
      >v{{ version }}</span>
    </div>

    <div class="flex items-center gap-1">
      <button
        class="p-1.5 rounded-lg text-slate-400 hover:text-brand-500 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        title="Обновить из dev-папки"
        @click="updateFromDev"
      >
        <RefreshCw class="w-4 h-4" />
      </button>
      <button
        class="p-1.5 rounded-lg text-slate-400 hover:text-brand-500 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        :title="isDark ? 'Светлая тема' : 'Тёмная тема'"
        @click="toggleTheme"
      >
        <Sun v-if="isDark" class="w-4 h-4" />
        <Moon v-else class="w-4 h-4" />
      </button>
    </div>
  </header>
</template>

<script setup>
import { FolderPlus, RefreshCw, Sun, Moon } from 'lucide-vue-next'
import { useTheme } from '../composables/useTheme'
import { updateFromDev } from '../composables/useSketchupBridge'

defineProps({ version: { type: String, default: '—' } })

const { isDark, toggleTheme } = useTheme()
</script>
