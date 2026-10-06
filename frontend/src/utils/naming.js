/**
 * Зеркало Ruby-логики Generator — для предпросмотра имён папок/файлов
 * в UI до создания структуры на диске.
 *
 * Шаблон '{articul} ~ {place}' + vars → сегменты по '~' очищаются от пустых
 * частей после запятой, пустые сегменты выбрасываются, сегменты склеиваются ' ~ '.
 */

export function fillTemplate(template, vars) {
  const filled = String(template || '').replace(/\{(\w+)\}/g, (m, key) =>
    Object.prototype.hasOwnProperty.call(vars, key) ? String(vars[key] ?? '') : ''
  )
  return filled
    .split('~')
    .map(s => compactCommas(s))
    .filter(s => s.trim().length > 0)
    .join(' ~ ')
}

export function compactCommas(text) {
  return text
    .split(',')
    .map(s => s.trim())
    .filter(s => s.length > 0)
    .join(', ')
}

export function productValue(_type, product) {
  return String(product || '').trim()
}

export function templateVars(type, order, articul, product, timestamp) {
  return {
    articul: articul || '',
    customer: order.customer || '',
    company: order.company || '',
    address: order.address || '',
    phone: order.phone || '',
    email: order.email || '',
    place: order.place || '',
    product: productValue(type, product),
    timestamp: timestamp || ''
  }
}

/** Метка времени артикула: yyMMdd_HHMMSS (зеркало Ruby %y%m%d_%H%M%S). */
export function makeTimestamp(date = new Date()) {
  const p = n => String(n).padStart(2, '0')
  return (
    String(date.getFullYear()).slice(2) +
    p(date.getMonth() + 1) + p(date.getDate()) +
    '_' + p(date.getHours()) + p(date.getMinutes()) + p(date.getSeconds())
  )
}

/** Артикул = префикс типа + метка времени (зеркало Generator.build_articul). */
export function buildArticul(settings, type, timestamp) {
  const s = settings || {}
  const prefix = type === 'commercial'
    ? (s.articul?.commercial_prefix ?? 'CF#')
    : (s.articul?.household_prefix ?? 'HF#')
  return `${prefix}${timestamp}`
}

/** Шаблон папки заказа (1-й уровень) для типа. */
export function orderTemplate(settings, type) {
  return settings?.structure?.folders?.[type]?.order ||
    (type === 'commercial' ? '{customer} ~ {company} ~ {address}' : '{customer} ~ {address}')
}

/** Шаблон папки проекта (2-й уровень) для типа. */
export function projectTemplate(settings, type) {
  return settings?.structure?.folders?.[type]?.project ||
    (type === 'commercial' ? '{place} ~ {product}' : '{place}')
}
