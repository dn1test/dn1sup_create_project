<template>
  <!-- Вопрос о типе проекта при открытии -->
  <TypeSelect v-if="!state.orderType" />

  <div v-else class="max-w-5xl mx-auto space-y-3 pb-4">
    <!-- Тип + смена -->
    <div class="flex items-center justify-between">
      <div class="cp-label flex items-center gap-2">
        <component :is="typeMeta.icon" class="w-4 h-4 text-brand-500" />
        {{ typeMeta.title }}
      </div>
      <button class="cp-btn-ghost !py-1 text-xs" @click="changeType">
        <Repeat class="w-3.5 h-3.5" /> Сменить тип
      </button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-[1fr,330px] gap-3 items-start">
      <!-- Левая колонка: проекты -->
      <section class="cp-card p-3 space-y-2">
        <div class="flex items-center justify-between">
          <div class="cp-label">Проекты <span class="text-slate-300">({{ form.projects.length }})</span></div>
          <button class="cp-btn-ghost !py-1 text-xs" @click="addProject">
            <Plus class="w-3.5 h-3.5" /> Добавить проект
          </button>
        </div>

        <ProjectRow
          v-for="(project, index) in form.projects"
          :key="project._id"
          :project="project"
          :index="index"
          :type="form.type"
          :settings="settings"
          :can-remove="form.projects.length > 1"
          :base-time="baseTime"
          @remove="removeProject(index)"
        />
      </section>

      <!-- Правая колонка: заказчик -->
      <section class="cp-card p-3 space-y-2 md:sticky md:top-0">
        <div class="cp-label">Заказчик</div>
        <Field
          v-model="form.order.customer"
          label="Имя заказчика"
          placeholder="Иван"
          required
        />
        <Field
          v-if="form.type === 'commercial'"
          v-model="form.order.company"
          label="Название фирмы"
          placeholder="ООО «Стройторг»"
          required
        />
        <Field v-model="form.order.phone" label="Телефон" placeholder="+375 29 123-45-67" />
        <Field v-model="form.order.email" label="Почта электронная" placeholder="ivan@mail.by" />
        <Field
          v-model="form.order.address"
          label="Адрес установки"
          placeholder="Минск, ул. Ленина 5"
          required
        />
      </section>
    </div>

    <!-- Куда сохранится -->
    <section class="cp-card p-3">
      <div class="flex items-center justify-between gap-2">
        <div class="min-w-0">
          <div class="cp-label">Директория проектов</div>
          <p
            v-if="rootFolder"
            class="text-[11px] font-mono text-slate-500 dark:text-slate-400 truncate"
            :title="rootFolder"
          >{{ rootFolder }}</p>
          <p v-else class="text-[11px] text-amber-500">
            Не задана — укажите её в Настройках, иначе создание будет недоступно.
          </p>
        </div>
        <button class="cp-btn-ghost shrink-0 !py-1 text-xs" @click="$emit('go-to-settings')">
          <Settings2 class="w-3.5 h-3.5" /> Настройки
        </button>
      </div>
    </section>

    <!-- Предпросмотр -->
    <section class="cp-card p-3">
      <div class="cp-label mb-2">Предпросмотр</div>
      <div class="space-y-1.5">
        <div v-for="(preview, index) in previews" :key="index" class="flex items-start gap-2 text-xs">
          <span class="cp-label shrink-0 pt-0.5 w-14 text-right">{{ index + 1 }}</span>
          <div class="min-w-0">
            <div class="font-mono text-[11px] text-slate-700 dark:text-slate-200 break-all">
              {{ preview.folder }}
            </div>
            <div class="text-[10px] text-slate-400 font-mono break-all">{{ preview.files }}</div>
          </div>
        </div>
        <p v-if="!previews.length" class="text-xs text-slate-400">
          Заполните место и продукт, чтобы увидеть структуру.
        </p>
      </div>
    </section>

    <!-- Действие -->
    <button class="cp-btn-primary w-full py-2.5" :disabled="!canCreate" @click="create">
      <FolderPlus class="w-4 h-4" />
      {{ form.projects.length > 1 ? `Создать проекты (${form.projects.length})` : 'Создать проект' }}
    </button>
  </div>
</template>

<script setup>
import { computed, defineEmits, reactive, ref, watch } from 'vue'
import { FolderPlus, House, Plus, Repeat, Settings2, Store } from 'lucide-vue-next'
import Field from './Field.vue'
import ProjectRow from './ProjectRow.vue'
import TypeSelect from './TypeSelect.vue'
import { state, createProjects, toast } from '../../composables/useSketchupBridge'
import {
  buildArticul, fillTemplate, orderTemplate,
  projectTemplate, templateVars, timestampWithOffset
} from '../../utils/naming'

const emit = defineEmits(['go-to-settings'])

const settings = computed(() => state.settings)

const typeMeta = computed(() => state.orderType === 'commercial'
  ? { title: 'Коммерческий проект', icon: Store }
  : { title: 'Бытовой проект', icon: House })

let projectSeq = 0
const form = reactive({
  type: null,
  order: { company: '', customer: '', phone: '', email: '', address: '' },
  projects: []
})

// базовая метка времени: проект №i получает метку +i секунд, артикулы различаются
const baseTime = ref(new Date())

// при выборе/смене типа — начинаем новый список проектов (данные заказчика сохраняем)
watch(
  () => state.orderType,
  (type) => {
    if (!type || type === form.type) return
    form.type = type
    form.projects = []
    addProject()
  },
  { immediate: true }
)

function addProject() {
  form.projects.push({ _id: ++projectSeq, place: '', product: '', groups: [] })
}

function removeProject(index) {
  form.projects.splice(index, 1)
}

function changeType() {
  state.orderType = null
}

const rootFolder = computed(() => settings.value?.defaults?.projects_root || '')

const previews = computed(() => {
  const s = settings.value
  if (!s || !form.type) return []
  return form.projects.map((project, index) => {
    const order = { ...form.order, place: project.place }
    const timestamp = timestampWithOffset(baseTime.value, index)
    const vars = templateVars(form.type, order, buildArticul(s, form.type, timestamp), project.product, timestamp)
    const orderFolder = fillTemplate(orderTemplate(s, form.type), vars)
    const projectFolder = fillTemplate(projectTemplate(s, form.type), vars)
    const skp = fillTemplate(s.naming.skp_file, vars)
    const pur = fillTemplate(s.naming.pur_file, vars)
    return {
      folder: `${orderFolder}/${projectFolder}`,
      files: `${skp}.skp · ${pur}.pur${project.groups.length ? ` · +${project.groups.reduce((n, g) => n + g.files.length, 0)} файлов` : ''}`
    }
  })
})

const canCreate = computed(() => {
  if (!rootFolder.value.trim()) return false
  if (!form.order.customer.trim() || !form.order.address.trim()) return false
  if (form.type === 'commercial' && !form.order.company.trim()) return false
  if (!form.projects.length) return false
  return form.projects.every((p) => {
    if (!p.place.trim() || !p.product.trim()) return false
    return p.groups.every(g => g.folder.trim().length > 0)
  })
})

function create() {
  const missing = !rootFolder.value.trim()
  if (missing) {
    toast('err', 'Укажите директорию проектов в Настройках')
    return
  }
  baseTime.value = new Date() // фиксируем метку пачки: +1 секунда на проект
  createProjects({
    type: form.type,
    order: { ...form.order },
    projects: form.projects.map(p => ({
      place: p.place.trim(),
      product: p.product.trim(),
      file_groups: p.groups
        .filter(g => g.files.length)
        .map(g => ({ folder: g.folder.trim(), paths: g.files.map(f => f.path) }))
    }))
  })
}
</script>
