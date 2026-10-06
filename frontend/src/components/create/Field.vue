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
        @input="$emit('update:modelValue', $event.target.value)"
      />
    </label>
  </div>
</template>

<script setup>
defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, required: true },
  placeholder: { type: String, default: '' },
  required: { type: Boolean, default: false }
})

defineEmits(['update:modelValue'])
</script>
