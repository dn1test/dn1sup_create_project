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
      <!-- Левая колонка: проекты-вкладки -->
      <section class="cp-card p-3 space-y-2">
        <div class="cp-label">Проекты <span class="text-slate-300">({{ form.projects.length }})</span></div>

        <!-- Полоса вкладок: каждая вкладка — отдельный проект -->
        <div v-if="form.projects.length" class="flex items-center gap-1 overflow-x-auto pb-0.5">
          <button
            v-for="(project, index) in form.projects"
            :key="project._id"
            class="shrink-0 flex items-center gap-1.5 pl-2.5 pr-1 py-1.5 rounded-lg border text-xs font-medium
                   transition-colors max-w-[220px]"
            :class="project._id === activeProjectId
              ? 'bg-white dark:bg-slate-700 border-brand-300 dark:border-brand-800 text-brand-600 dark:text-brand-300 shadow-sm'
              : 'bg-slate-100/70 dark:bg-slate-900 border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'"
            :title="projectTitle(project, index)"
            @click="activeProjectId = project._id"
          >
            <span
              v-if="!projectComplete(project)"
              class="w-1.5 h-1.5 rounded-full bg-amber-400 shrink-0"
              title="Проект заполнен не полностью"
            ></span>
            <span class="truncate">{{ projectTitle(project, index) }}</span>
            <span
              class="shrink-0 rounded p-0.5 text-slate-400 hover:bg-red-500 hover:text-white transition-colors"
              title="Закрыть вкладку"
              @click.stop="removeProject(index)"
            >
              <X class="w-3 h-3" />
            </span>
          </button>

          <button
            class="shrink-0 w-7 h-7 rounded-lg flex items-center justify-center text-slate-400
                   hover:text-brand-500 hover:bg-brand-50 dark:hover:bg-slate-800 transition-colors"
            title="Добавить проект"
            @click="addProject"
          >
            <Plus class="w-4 h-4" />
          </button>
        </div>

        <!-- Вкладку по умолчанию не создаём: стартуем с пустого состояния -->
        <div
          v-else
          class="rounded-lg border border-dashed border-slate-300 dark:border-slate-700
                 p-6 flex flex-col items-center gap-2.5"
        >
          <p class="text-xs text-slate-400 text-center leading-relaxed">
            Проектов пока нет. Каждая вкладка — отдельный проект<br />со своими файлами.
          </p>
          <button class="cp-btn-primary !py-1.5 text-xs" @click="addProject">
            <Plus class="w-3.5 h-3.5" /> Добавить проект
          </button>
        </div>

        <!-- Панель активного проекта -->
        <ProjectRow
          v-if="activeProject"
          :key="activeProject._id"
          :project="activeProject"
          :index="activeIndex"
          :type="form.type"
          :settings="settings"
          @remove="removeProject(activeIndex)"
        />
      </section>

      <!-- Правая колонка: заказчик + предпросмотр -->
      <div class="space-y-3 md:sticky md:top-0">
        <section class="cp-card p-3 space-y-2">
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

        <!-- Предпросмотр -->
        <section class="cp-card p-3">
          <div class="cp-label mb-2">Предпросмотр</div>
          <div class="space-y-1.5">
            <div v-for="(preview, index) in previews" :key="index" class="flex items-start gap-2 text-xs">
              <span class="cp-label shrink-0 pt-0.5 w-6 text-right">{{ index + 1 }}</span>
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
      </div>
    </div>

    <!-- Предупреждение: директория проектов выбирается только в Настройках -->
    <section v-if="!rootFolder" class="cp-card p-3 border border-amber-300 dark:border-amber-800">
      <div class="flex items-center justify-between gap-2">
        <p class="text-xs text-amber-600 dark:text-amber-400">
          Директория проектов не задана — выберите её в Настройках, иначе создание недоступно.
        </p>
        <button class="cp-btn-ghost shrink-0 !py-1 text-xs" @click="$emit('go-to-settings')">
          <Settings2 class="w-3.5 h-3.5" /> Настройки
        </button>
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
import { FolderPlus, House, Plus, Repeat, Settings2, Store, X } from 'lucide-vue-next'
import Field from './Field.vue'
import ProjectRow from './ProjectRow.vue'
import TypeSelect from './TypeSelect.vue'
import { state, createProjects, toast } from '../../composables/useSketchupBridge'
import {
  fillTemplate, orderTemplate, projectTemplate, templateVars
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

// активная вкладка; вкладку по умолчанию не создаём — список стартует пустым
const activeProjectId = ref(null)
const activeIndex = computed(() => form.projects.findIndex(p => p._id === activeProjectId.value))
const activeProject = computed(() => activeIndex.value >= 0 ? form.projects[activeIndex.value] : null)

// при выборе/смене типа — чистый лист (данные заказчика сохраняем)
watch(
  () => state.orderType,
  (type) => {
    if (!type || type === form.type) return
    form.type = type
    form.projects = []
    activeProjectId.value = null
  },
  { immediate: true }
)

function addProject() {
  const project = { _id: ++projectSeq, place: '', product: '', groups: [] }
  form.projects.push(project)
  activeProjectId.value = project._id
}

function removeProject(index) {
  const wasActive = form.projects[index]._id === activeProjectId.value
  form.projects.splice(index, 1)
  if (!form.projects.length) {
    activeProjectId.value = null
  } else if (wasActive) {
    activeProjectId.value = form.projects[Math.min(index, form.projects.length - 1)]._id
  }
}

// заголовок вкладки: место и продукт, пока не заполнены — «Проект N»
function projectTitle(project, index) {
  const parts = [project.place.trim(), project.product.trim()].filter(Boolean)
  return parts.length ? parts.join(' ~ ') : `Проект ${index + 1}`
}

// вкладка заполнена достаточно для создания (та же проверка, что в canCreate)
function projectComplete(project) {
  if (!project.place.trim() || !project.product.trim()) return false
  return project.groups.every(g => g.folder.trim().length > 0)
}

// после успешного создания начинаем новую пачку (данные заказчика остаются)
watch(
  () => state.lastCreated,
  (at) => {
    if (!at) return
    form.projects = []
    activeProjectId.value = null
  }
)

function changeType() {
  state.orderType = null
}

const rootFolder = computed(() => settings.value?.defaults?.projects_root || '')

const previews = computed(() => {
  const s = settings.value
  if (!s || !form.type) return []
  return form.projects.map((project) => {
    const order = { ...form.order, place: project.place }
    const vars = templateVars(form.type, order, project.product)
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
