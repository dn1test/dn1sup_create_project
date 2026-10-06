<template>
  <header
    class="px-3.5 py-2.5 flex items-center justify-between border-b border-slate-200/70 dark:border-slate-800/70 shrink-0"
  >
    <div class="flex items-center gap-2 min-w-0">
      <div class="w-7 h-7 rounded-lg bg-brand-500 flex items-center justify-center shrink-0">
        <FolderPlus class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0">
        <h1 class="text-sm font-semibold leading-tight truncate">Создание проекта</h1>
        <p class="text-[10px] text-slate-400 dark:text-slate-500 leading-tight">
          структура мебельных проектов
        </p>
      </div>
      <span
        class="ml-1 px-1.5 py-0.5 rounded bg-slate-200/70 dark:bg-slate-800 text-[10px] font-mono text-slate-500 dark:text-slate-400"
      >v{{ version }}</span>
    </div>

    <div class="flex items-center gap-1">
      <!-- Артикул текущего заказа -->
      <span
        v-if="articul"
        class="mr-1 px-2 py-1 rounded-md bg-brand-50 dark:bg-brand-950/50 border border-brand-200 dark:border-brand-900
               text-[11px] font-mono font-semibold text-brand-600 dark:text-brand-300"
        :title="`Артикул проекта (${orderTypeLabel})`"
      >{{ articul }}</span>
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
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { FolderPlus, RefreshCw, Sun, Moon } from 'lucide-vue-next'
import { useTheme } from '../composables/useTheme'
import { state, updateFromDev } from '../composables/useSketchupBridge'
import { buildArticul, makeTimestamp } from '../utils/naming'

defineProps({ version: { type: String, default: '—' } })

const { isDark, toggleTheme } = useTheme()

const now = ref(new Date())
let timer = null
onMounted(() => {
  timer = setInterval(() => { now.value = new Date() }, 1000)
})
onUnmounted(() => {
  if (timer) clearInterval(timer)
})

const articul = computed(() => {
  if (!state.orderType || !state.settings) return ''
  return buildArticul(state.settings, state.orderType, makeTimestamp(now.value))
})

const orderTypeLabel = computed(() => (state.orderType === 'commercial' ? 'коммерческий' : 'бытовой'))
</script>
