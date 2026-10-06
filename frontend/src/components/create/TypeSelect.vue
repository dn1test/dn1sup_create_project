<template>
  <div class="max-w-3xl mx-auto pt-6 pb-4">
    <h2 class="text-base font-semibold text-center">Создание проекта</h2>
    <p class="text-xs text-slate-400 text-center mt-1 mb-5">Какой проект создаём?</p>

    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <button
        v-for="t in types"
        :key="t.id"
        class="cp-card p-5 text-left border-2 transition-all hover:border-brand-400 hover:shadow-md"
        :class="t.accent"
        @click="state.orderType = t.id"
      >
        <div class="w-11 h-11 rounded-xl flex items-center justify-center mb-3" :class="t.iconBg">
          <component :is="t.icon" class="w-5.5 h-5.5 text-white" />
        </div>
        <div class="text-sm font-semibold">{{ t.title }}</div>
        <p class="text-[11px] text-slate-400 mt-1 leading-relaxed">{{ t.hint }}</p>
      </button>
    </div>
  </div>
</template>

<script setup>
import { House, Store } from 'lucide-vue-next'
import { state } from '../../composables/useSketchupBridge'

const types = [
  {
    id: 'commercial',
    title: 'Коммерческий проект',
    hint: 'Торговая мебель, острова, павильоны для ТЦ и бизнеса. Папка заказа включает название фирмы.',
    icon: Store,
    iconBg: 'bg-brand-500',
    accent: 'border-brand-200 dark:border-brand-900'
  },
  {
    id: 'household',
    title: 'Бытовой проект',
    hint: 'Мебель для квартиры или дома: кухня, шкафы, прихожая. Папка заказа — заказчик и адрес.',
    icon: House,
    iconBg: 'bg-emerald-500',
    accent: 'border-emerald-200 dark:border-emerald-900'
  }
]
</script>
