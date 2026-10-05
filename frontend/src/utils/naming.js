/**
 * Зеркало Ruby-логики Generator.fill_template — для предпросмотра имён
 * папок/файлов в UI до создания структуры на диске.
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

export function productValue(type, products) {
  const list = (products || []).filter(p => String(p || '').trim().length > 0)
  if (!list.length) return ''
  if (type === 'commercial' || list.length === 1) return list[0]
  return list.join(', ')
}

export function templateVars(type, order, articul, products, timestamp) {
  return {
    articul: articul || '',
    customer: order.customer || '',
    company: order.company || '',
    address: order.address || '',
    place: order.place || '',
    product: productValue(type, products),
    timestamp: timestamp || ''
  }
}
