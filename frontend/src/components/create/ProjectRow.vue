<template>
  <div class="rounded-lg border border-slate-200 dark:border-slate-800 p-2.5 space-y-2">
    <div class="flex items-center justify-between">
      <div class="text-xs font-semibold text-slate-500 dark:text-slate-400">
        Проект {{ index + 1 }}
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

    <div class="grid gap-2 grid-cols-1">
      <div>
        <label class="block">
          <span class="block mb-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400">
            {{ type === 'commercial' ? 'Место установки' : 'Место расположения' }}<span class="text-brand-500"> *</span>
          </span>
          <input
            :value="project.place"
            type="text"
            class="cp-input"
            :placeholder="type === 'commercial' ? 'ТЦ, павильон, улица или другое место' : 'Кухня, гостиная…'"
            :list="placesListId"
            @input="project.place = $event.target.value"
          />
          <datalist v-if="placesOptions.length" :id="placesListId">
            <option v-for="option in placesOptions" :key="option" :value="option" />
          </datalist>
        </label>
      </div>

      <div>
        <span class="block mb-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400">
          Мебель<span class="text-brand-500"> *</span>
        </span>

        <!-- Выбранные позиции (чипы) -->
        <div v-if="project.products.length" class="flex flex-wrap gap-1 mb-1.5">
          <span
            v-for="(product, pi) in project.products"
            :key="`${product}-${pi}`"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-brand-50 dark:bg-brand-950/50 border border-brand-200 dark:border-brand-900 text-brand-600 dark:text-brand-300 text-[11px] font-medium"
          >
            {{ product }}
            <button class="hover:text-red-500" @click="removeProduct(pi)">
              <X class="w-3 h-3" />
            </button>
          </span>
        </div>

        <div class="flex gap-1.5">
          <input
            v-model="productDraft"
            type="text"
            class="cp-input"
            :placeholder="productPlaceholder"
            :list="productsListId"
            @keydown.enter="commitDraftSoon"
            @blur="addProduct(productDraft)"
          />
          <select
            v-if="suggestions.length"
            class="cp-input !w-auto shrink-0 text-xs"
            value=""
            @change="addProduct($event.target.value); $event.target.value = ''"
          >
            <option value="" disabled>из списка…</option>
            <option v-for="option in suggestions" :key="option" :value="option">{{ option }}</option>
          </select>
          <button class="cp-btn-ghost shrink-0" title="Добавить" @click="addProduct(productDraft)">
            <Plus class="w-4 h-4" />
          </button>
        </div>
        <datalist v-if="suggestions.length" :id="productsListId">
          <option v-for="option in suggestions" :key="option" :value="option" />
        </datalist>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { Trash2, X, Plus } from 'lucide-vue-next'

const props = defineProps({
  project: { type: Object, required: true },
  index: { type: Number, required: true },
  type: { type: String, required: true },
  settings: { type: Object, default: null },
  canRemove: { type: Boolean, default: true }
})

defineEmits(['remove'])

const productDraft = ref('')
const placesListId = `places-${Math.random().toString(36).slice(2, 9)}`
const productsListId = `products-${Math.random().toString(36).slice(2, 9)}`

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
  props.type === 'commercial' ? 'Название мебели — выберите или введите своё' : 'Мебель — выберите или введите своё'
)

function addProduct(value) {
  const v = String(value || '').trim()
  if (!v) return
  if (props.type === 'commercial') {
    props.project.products = [v]
  } else if (!props.project.products.includes(v)) {
    props.project.products.push(v)
  }
  productDraft.value = ''
}

// Enter при открытой подсказке datalist: input-событие с принятым значением
// приходит после keydown, поэтому коммитим на следующем тике
function commitDraftSoon() {
  setTimeout(() => addProduct(productDraft.value), 0)
}

function removeProduct(index) {
  props.project.products.splice(index, 1)
}
</script>
