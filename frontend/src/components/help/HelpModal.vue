<script setup>
import { FolderPlus, RefreshCw, Sun, Moon } from 'lucide-vue-next'
import { state } from '../../composables/useSketchupBridge'
import Modal from '../Modal.vue'

defineProps({
  open: { type: Boolean, default: false }
})
defineEmits(['close'])

const steps = [
  'Во вкладке «Настройки» укажите <b>директорию проектов</b> — корневую папку, куда всё будет создаваться.',
  'Во вкладке «Создать» выберите тип: <b>бытовой</b> (квартира, дом) или <b>коммерческий</b> (ТЦ, бизнес).',
  'Заполните данные заказчика: имя, для коммерческих — название фирмы, а также телефон, почту и адрес установки.',
  'Нажмите <b>«Добавить проект»</b> — каждая вкладка сверху это отдельный проект. Укажите место установки и продукт, при необходимости приложите файлы: кнопки «Добавить файлы» и «Папку» раскладывают их по именованным подпапкам.',
  'Справа в «Предпросмотре» проверьте будущую структуру папок и файлов.',
  'Нажмите <b>«Создать проект»</b> — структура появится на диске, а проекты зарегистрируются в расширении.'
]

const tree = `корень проектов/
└── Заказчик ~ Компания ~ Адрес/          (папка заказа)
    └── Место ~ Продукт/                  (папка проекта)
        ├── Место ~ Продукт.skp           (копия template.skp)
        ├── Место.pur                     (копия template.pur)
        ├── Место.yaml                    (карточка + история)
        └── Фото ТЦ/…                     (группы добавленных файлов)`

const placeholders = [
  { code: '{customer}', text: 'имя заказчика' },
  { code: '{company}', text: 'название фирмы (коммерческий)' },
  { code: '{address}', text: 'адрес установки' },
  { code: '{phone}', text: 'телефон' },
  { code: '{email}', text: 'электронная почта' },
  { code: '{place}', text: 'место установки / комната' },
  { code: '{product}', text: 'продукт / название мебели' }
]
</script>

<template>
  <Modal
    :open="open"
    title="Как пользоваться Create Project"
    max-width="max-w-2xl"
    body-class="max-h-[72vh]"
    @close="$emit('close')"
  >
    <div class="space-y-4 text-xs leading-relaxed text-slate-600 dark:text-slate-300">
      <section class="space-y-2">
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 rounded-lg bg-brand-500 flex items-center justify-center shrink-0">
            <FolderPlus class="w-4 h-4 text-white" />
          </div>
          <div>
            <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">DN1Sup Create Project</h4>
            <p class="text-[10px] text-slate-400">версия {{ state.version }}</p>
          </div>
        </div>
        <p>
          Расширение SketchUp для быстрого создания мебельных проектов. За один запуск оно
          строит структуру папок на диске: папку заказа → папки проектов, копирует в каждый
          проект шаблоны <span class="font-mono">.skp</span> и <span class="font-mono">.pur</span>,
          создаёт YAML-карточку с историей и раскладывает добавленные изображения и документы
          по именованным подпапкам.
        </p>
      </section>

      <section class="space-y-2">
        <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">Быстрый старт</h4>
        <ol class="space-y-2">
          <li v-for="(step, i) in steps" :key="i" class="flex items-start gap-2.5">
            <span
              class="shrink-0 w-5 h-5 rounded-full bg-brand-100 dark:bg-brand-900/60 text-brand-700 dark:text-brand-300
                     text-[11px] font-semibold flex items-center justify-center mt-px"
            >{{ i + 1 }}</span>
            <p class="leading-relaxed" v-html="step" />
          </li>
        </ol>
      </section>

      <section class="space-y-1">
        <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">Что создаётся на диске</h4>
        <pre class="font-mono text-[11px] leading-relaxed text-slate-600 dark:text-slate-300
                    bg-slate-100/70 dark:bg-slate-900/70 rounded-lg p-3 overflow-x-auto">{{ tree }}</pre>
        <p class="text-[11px] text-slate-400">
          Если папка или файл с таким именем уже есть, к имени добавляется счётчик:
          «Кухня (2)», «Кухня (3)»… Имена папок и файлов — шаблоны, настраиваются во вкладке
          «Настройки».
        </p>
      </section>

      <section class="space-y-1">
        <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">Плейсхолдеры шаблонов</h4>
        <p class="text-[11px] text-slate-400">
          В шаблонах папок и имён файлов можно использовать подстановки — при создании
          они заменяются данными заказа и проекта:
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-1">
          <div v-for="ph in placeholders" :key="ph.code" class="flex items-baseline gap-2">
            <code class="font-mono text-brand-600 dark:text-brand-400 shrink-0">{{ ph.code }}</code>
            <span class="text-slate-500 dark:text-slate-400">{{ ph.text }}</span>
          </div>
        </div>
        <p class="text-[11px] text-slate-400">
          Сегменты, разделённые «~», из которых данные не заполнены, исчезают из имени сами.
        </p>
      </section>

      <section class="space-y-1">
        <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">Настройки</h4>
        <ul class="space-y-1.5 leading-relaxed">
          <li><b>Директория проектов</b> — корневая папка, в которой создаются все проекты.</li>
          <li><b>Папки бытового и коммерческого проекта</b> — шаблоны папки заказа (1-й уровень)
            и папок проектов (2-й уровень).</li>
          <li><b>Шаблоны файлов</b> — файлы template.skp / template.pur, которые копируются в каждый
            проект, и правила именования .skp, .pur и YAML-карточки.</li>
          <li><b>Сбросить</b> — вернуть все настройки к значениям по умолчанию.</li>
        </ul>
        <p class="text-[11px] text-slate-400">
          Настройки хранятся в YAML и переживают переустановку расширения: файл можно открыть
          кнопкой внизу окна и править вручную.
        </p>
      </section>

      <section class="space-y-1">
        <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">Карточка проекта</h4>
        <p>
          В каждой папке проекта лежит YAML-карточка (два документа: данные проекта и история
          изменений). Это источник истины о проекте: реестр хранит только пути, поэтому
          зарегистрировать можно и чужую папку — карточка создастся при первом открытии.
        </p>
      </section>

      <section class="space-y-1">
        <h4 class="text-xs font-semibold text-slate-800 dark:text-slate-100">Интерфейс</h4>
        <ul class="space-y-1.5 leading-relaxed">
          <li>Кнопка <HelpCircle class="w-3.5 h-3.5 inline -mt-0.5 text-slate-400" /> в шапке — эта справка.</li>
          <li>Кнопка <RefreshCw class="w-3.5 h-3.5 inline -mt-0.5 text-slate-400" /> — обновить
            расширение из dev-папки без перезапуска SketchUp.</li>
          <li>Кнопки <Sun class="w-3.5 h-3.5 inline -mt-0.5 text-slate-400" />/<Moon class="w-3.5 h-3.5 inline -mt-0.5 text-slate-400" /> —
            светлая и тёмная тема.</li>
          <li>Строка внизу окна — путь к settings.yaml, кнопка «открыть» показывает файл в Проводнике.</li>
        </ul>
      </section>
    </div>
    <template #footer>
      <button class="cp-btn-primary" @click="$emit('close')">Понятно</button>
    </template>
  </Modal>
</template>
