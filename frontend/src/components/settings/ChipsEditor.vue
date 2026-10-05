<template>
  <div>
    <div v-if="chips.length" class="flex flex-wrap gap-1 mb-1.5">
      <span
        v-for="(chip, index) in chips"
        :key="`${chip}-${index}`"
        class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-brand-50 dark:bg-brand-950/50 border border-brand-200 dark:border-brand-900 text-brand-600 dark:text-brand-300 text-[11px] font-medium"
      >
        {{ chip }}
        <button class="hover:text-red-500" @click="remove(index)">
          <X class="w-3 h-3" />
        </button>
      </span>
    </div>
    <input
      v-model="draft"
      type="text"
      class="cp-input !py-1 text-xs"
      :placeholder="placeholder"
      @keydown.enter.prevent="add"
      @blur="add"
    />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { X } from 'lucide-vue-next'

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  placeholder: { type: String, default: 'введите и нажмите Enter' }
})

const emit = defineEmits(['update:modelValue'])

const draft = ref('')

const chips = computed(() => props.modelValue || [])

function add() {
  const v = draft.value.trim()
  draft.value = ''
  if (!v) return
  if (!chips.value.includes(v)) emit('update:modelValue', [...chips.value, v])
}

function remove(index) {
  const next = [...chips.value]
  next.splice(index, 1)
  emit('update:modelValue', next)
}
</script>
