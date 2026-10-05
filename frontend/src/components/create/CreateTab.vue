<template>
  <div class="space-y-3 max-w-3xl mx-auto">
    <!-- Тип продукта -->
    <section class="cp-card p-3">
      <div class="cp-label mb-2">Тип продукта</div>
      <div class="grid grid-cols-2 gap-2">
        <button
          v-for="t in types"
          :key="t.id"
          class="cp-btn justify-start px-3 py-2 border"
          :class="form.type === t.id
            ? 'border-brand-500 bg-brand-50 dark:bg-brand-950/40 text-brand-600 dark:text-brand-300'
            : 'border-slate-200 dark:border-slate-800 text-slate-500 dark:text-slate-400 hover:border-brand-300'"
          @click="setType(t.id)"
        >
          <component :is="t.icon" class="w-4 h-4 shrink-0" />
          <span>{{ t.label }}</span>
        </button>
      </div>
    </section>

    <!-- Данные заказа -->
    <section class="cp-card p-3 space-y-2">
      <div class="cp-label">Данные заказа</div>
      <div v-if="form.type === 'commercial'" class="grid grid-cols-2 gap-2">
        <Field v-model="form.order.company" label="Название фирмы" placeholder="ООО «Стройторг»" required />
        <Field v-model="form.order.customer" label="Имя заказчика" placeholder="Иван" required />
      </div>
      <Field
        v-else
        v-model="form.order.customer"
        label="Заказчик (имя)"
        placeholder="Иван"
        required
      />
      <Field
        v-model="form.order.address"
        :label="form.type === 'commercial' ? 'Адрес (город или город, улица)' : 'Адрес установки'"
        placeholder="Минск, ул. Ленина 5"
        required
      />
    </section>

    <!-- Проекты -->
    <section class="cp-card p-3 space-y-2">
      <div class="flex items-center justify-between">
        <div class="cp-label">Проекты <span class="text-slate-300">({{ form.projects.length }})</span></div>
        <button class="cp-btn-ghost !py-1 text-xs" @click="addProject">
          <Plus class="w-3.5 h-3.5" /> Добавить проект
        </button>
      </div>

      <p v-if="form.type === 'household'" class="text-[11px] text-slate-400">
        Артикулы бытовых проектов перенумеровываются при добавлении и удалении: {{ householdPrefix }}&lt;время&gt;01, 02, …
      </p>

      <ProjectRow
        v-for="(project, index) in form.projects"
        :key="index"
        :project="project"
        :index="index"
        :type="form.type"
        :settings="settings"
        :can-remove="form.projects.length > 1"
        @remove="removeProject(index)"
      />
    </section>

    <!-- Куда сохранить -->
    <section class="cp-card p-3 space-y-2">
      <div class="cp-label">Корневая папка</div>
      <div class="flex gap-2">
        <input
          v-model="rootFolder"
          type="text"
          class="cp-input font-mono text-xs"
          placeholder="Выберите папку, в которой будут созданы проекты"
        />
        <button class="cp-btn-ghost shrink-0" @click="chooseRoot">
          <FolderOpen class="w-4 h-4" /> Выбрать…
        </button>
      </div>
      <p v-if="form.type === 'household' && orderFolderPreview" class="text-[11px] text-slate-400 truncate">
        Внутри будет создана папка заказа: <span class="font-mono">{{ orderFolderPreview }}</span>
      </p>
    </section>

    <!-- Предпросмотр -->
    <section class="cp-card p-3">
      <div class="cp-label mb-2">Предпросмотр</div>
      <div class="space-y-1.5">
        <div v-for="(preview, index) in previews" :key="index" class="flex items-start gap-2 text-xs">
          <span class="cp-label shrink-0 pt-0.5 w-14 text-right">{{ index + 1 }}</span>
          <div class="min-w-0">
            <div class="font-mono text-[11px] text-slate-700 dark:text-slate-200 break-all">{{ preview.folder }}</div>
            <div class="text-[10px] text-slate-400 font-mono break-all">{{ preview.files }}</div>
          </div>
        </div>
        <p v-if="!previews.length" class="text-xs text-slate-400">
          Заполните место установки, чтобы увидеть структуру.
        </p>
      </div>
    </section>

    <!-- Действие -->
    <button class="cp-btn-primary w-full py-2.5" :disabled="!canCreate" @click="create">
      <FolderPlus class="w-4 h-4" />
      {{ form.type === 'commercial' ? 'Создать проект' : `Создать проекты (${form.projects.length})` }}
    </button>
  </div>
</template>

<script setup>
import { reactive, computed, ref } from 'vue'
import { Store, House, Plus, FolderOpen, FolderPlus } from 'lucide-vue-next'
import Field from './Field.vue'
import ProjectRow from './ProjectRow.vue'
import { state, pickFolder, createProjects, toast } from '../../composables/useSketchupBridge'
import { fillTemplate, templateVars } from '../../utils/naming'

const types = [
  { id: 'commercial', label: 'Коммерческий продукт', icon: Store },
  { id: 'household', label: 'Бытовой продукт', icon: House }
]

const settings = computed(() => state.settings)
const rootFolder = ref('')

const form = reactive({
  type: 'commercial',
  order: { company: '', customer: '', address: '' },
  projects: [{ place: '', products: [] }] // мастер всегда начинается с одной строки проекта
})

function setType(type) {
  form.type = type
  form.projects = []
  addProject()
}

function addProject() {
  form.projects.push({ place: '', products: [] })
}

function removeProject(index) {
  form.projects.splice(index, 1)
}

function makeTimestamp() {
  const d = new Date()
  const p = (n, w = 2) => String(n).padStart(w, '0')
  return String(d.getFullYear()).slice(2) + p(d.getMonth() + 1) + p(d.getDate()) + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds())
}

const timestamp = ref(makeTimestamp())

const articulPreview = computed(() => {
  const s = settings.value
  if (!s) return ''
  return (n) => {
    if (form.type === 'commercial') {
      return `${s.articul.commercial_prefix}${timestamp.value}`
    }
    return `${s.articul.household_prefix}${timestamp.value}${String(n).padStart(2, '0')}`
  }
})

const householdPrefix = computed(() => settings.value?.articul.household_prefix || 'HF#')

const orderFolderPreview = computed(() => {
  const s = settings.value
  if (!s) return ''
  return fillTemplate(s.naming.household_order_folder, {
    customer: form.order.customer,
    address: form.order.address
  })
})

const previews = computed(() => {
  const s = settings.value
  if (!s) return []
  return form.projects.map((project, index) => {
    const order = { ...form.order, place: project.place }
    const vars = templateVars(form.type, order, articulPreview.value(index + 1), project.products, timestamp.value)
    const folderTpl = form.type === 'commercial' ? s.naming.commercial_folder : s.naming.household_project_folder
    const folder = fillTemplate(folderTpl, vars)
    const files = form.type === 'commercial'
      ? `${fillTemplate(s.naming.commercial_file, vars)}.skp / .pur`
      : `${fillTemplate(s.naming.household_skp_file, vars)}.skp, ${fillTemplate(s.naming.pur_file, vars)}.pur`
    return { folder: `${form.type === 'household' ? orderFolderPreview.value + '/' : ''}${folder}`, files }
  })
})

const canCreate = computed(() =>
  rootFolder.value.trim().length > 0 &&
  form.order.customer.trim().length > 0 &&
  form.order.address.trim().length > 0 &&
  form.projects.length > 0 &&
  form.projects.every(p => p.place.trim().length > 0 && p.products.some(pr => pr.trim().length > 0))
)

async function chooseRoot() {
  const path = await pickFolder('root')
  if (path) rootFolder.value = path
}

function create() {
  createProjects({
    type: form.type,
    base_path: rootFolder.value.trim(),
    order: { ...form.order },
    projects: form.projects.map(p => ({ place: p.place.trim(), products: p.products.filter(x => x.trim()) }))
  })
}
</script>
