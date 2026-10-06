<template>
  <div class="h-full flex flex-col bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-100 transition-colors">
    <Header :version="state.version" />

    <nav class="px-3 pt-1.5 shrink-0">
      <div class="flex gap-1 bg-slate-200/60 dark:bg-slate-900 rounded-lg p-0.5">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          class="flex-1 flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-md text-xs font-medium transition-colors"
          :class="activeTab === tab.id
            ? 'bg-white dark:bg-slate-700 text-brand-600 dark:text-brand-400 shadow-sm'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'"
          @click="activeTab = tab.id"
        >
          <component :is="tab.icon" class="w-3.5 h-3.5" />
          <span>{{ tab.label }}</span>
          <span
            v-if="tab.badge"
            class="ml-0.5 px-1.5 py-px rounded-full bg-brand-100 dark:bg-brand-900/60 text-brand-700 dark:text-brand-300 text-[10px] font-semibold"
          >{{ tab.badge }}</span>
        </button>
      </div>
    </nav>

    <main class="flex-1 overflow-y-auto p-3">
      <KeepAlive>
        <CreateTab v-if="activeTab === 'create'" @go-to-settings="activeTab = 'settings'" />
        <SettingsTab v-else-if="activeTab === 'settings'" />
      </KeepAlive>
    </main>

    <footer
      v-if="state.settingsPath"
      class="px-3.5 py-1.5 bg-white/70 dark:bg-slate-900/70 border-t border-slate-200/70 dark:border-slate-800/70
             flex items-center justify-between text-[10px] text-slate-400 dark:text-slate-500 shrink-0"
    >
      <div class="flex items-center gap-1 truncate">
        <span class="w-1.5 h-1.5 rounded-full" :class="state.ready ? 'bg-emerald-400' : 'bg-slate-300'"></span>
        <span class="truncate" :title="state.settingsPath">settings.yaml</span>
      </div>
      <button class="hover:text-brand-500 underline-offset-2 hover:underline" @click="openSettingsFile">
        открыть
      </button>
    </footer>

    <!-- Тост -->
    <transition name="toast">
      <div
        v-if="state.toast"
        class="fixed bottom-10 left-1/2 -translate-x-1/2 px-3.5 py-2 rounded-lg shadow-lg text-xs font-medium flex items-center gap-2"
        :class="state.toast.kind === 'ok'
          ? 'bg-emerald-500 text-white'
          : 'bg-red-500 text-white'"
      >
        <CheckCircle v-if="state.toast.kind === 'ok'" class="w-3.5 h-3.5" />
        <AlertCircle v-else class="w-3.5 h-3.5" />
        <span class="max-w-[420px]">{{ state.toast.text }}</span>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { FolderPlus, Settings2, CheckCircle, AlertCircle } from 'lucide-vue-next'
import Header from './components/Header.vue'
import CreateTab from './components/create/CreateTab.vue'
import SettingsTab from './components/settings/SettingsTab.vue'
import { state, loadState, openSettingsFile } from './composables/useSketchupBridge'

const activeTab = ref('create')
const tabs = computed(() => [
  { id: 'create', label: 'Создать', icon: FolderPlus },
  { id: 'settings', label: 'Настройки', icon: Settings2 }
])

onMounted(() => {
  loadState()
})
</script>

<style>
.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translate(-50%, 8px);
}
</style>
