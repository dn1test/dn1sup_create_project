<template>
  <div class="cp-input !py-1.5">
    <label class="block">
      <span class="block mb-0.5 text-[11px] font-medium" :class="required ? 'text-slate-500 dark:text-slate-400' : 'text-slate-400'">
        {{ label }}<span v-if="required" class="text-brand-500"> *</span>
      </span>
      <input
        :value="modelValue"
        type="text"
        class="w-full bg-transparent text-sm text-inherit placeholder-slate-300 dark:placeholder-slate-600"
        :placeholder="placeholder"
        :list="listId"
        @input="$emit('update:modelValue', $event.target.value)"
      />
      <datalist v-if="options && options.length" :id="listId">
        <option v-for="option in options" :key="option" :value="option" />
      </datalist>
    </label>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, required: true },
  placeholder: { type: String, default: '' },
  required: { type: Boolean, default: false },
  options: { type: Array, default: null }
})

defineEmits(['update:modelValue'])

const listId = computed(() => `dl-${Math.random().toString(36).slice(2, 9)}`)
</script>
