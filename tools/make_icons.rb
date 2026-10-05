# frozen_string_literal: true
# =============================================================================
# tools/make_icons.rb — генерация иконок тулбара (cp_16.png, cp_24.png)
# чистым Ruby: пиксельная отрисовка «папка с плюсом» и сборка PNG через zlib.
# Запуск: ruby tools/make_icons.rb
# =============================================================================

require 'zlib'
require 'fileutils'

# -- сборка PNG из пиксельной канвы ------------------------------------------

def png_chunk(type, data)
  [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
end

def write_png(path, canvas)
  height = canvas.pixels.size
  width = canvas.pixels[0].size
  raw = canvas.pixels.map { |row| "\x00" + row.map { |px| px.pack('C4') }.join }.join
  png = "\x89PNG\r\n\x1a\n".b +
        png_chunk('IHDR', [width, height, 8, 6, 0, 0, 0].pack('N5')) +
        png_chunk('IDAT', Zlib::Deflate.deflate(raw)) +
        png_chunk('IEND', '')
  File.binwrite(path, png)
  puts "  ✓ #{path} (#{width}x#{height})"
end

# -- канва и примитивы --------------------------------------------------------

class Canvas
  attr_reader :pixels

  def initialize(w, h)
    @w = w
    @h = h
    @pixels = Array.new(h) { Array.new(w) { [0, 0, 0, 0] } }
  end

  def rect(x0, y0, x1, y1, color)
    (y0..y1).each do |y|
      (x0..x1).each do |x|
        @pixels[y][x] = color if x.between?(0, @w - 1) && y.between?(0, @h - 1)
      end
    end
  end
end

BLUE      = [12, 142, 233, 255].freeze  # #0c8ee9
BLUE_DARK = [1, 89, 149, 255].freeze    # #015995
WHITE     = [255, 255, 255, 255].freeze

# Папка с плюсом: канва w×h, геометрия — {body:[x0,y0,x1,y1], tab:[...], plus:{cx,cy,arm}}
def draw_icon(w, h, g)
  canvas = Canvas.new(w, h)
  bx0, by0, bx1, by1 = g[:body]
  tx0, ty0, tx1, ty1 = g[:tab]

  # заливка, затем контур: пиксель заливки на границе (сосед вне фигуры) красим тёмным
  filled = Array.new(h) { Array.new(w, false) }
  (by0..by1).each { |y| (bx0..bx1).each { |x| filled[y][x] = true } }
  (ty0..ty1).each { |y| (tx0..tx1).each { |x| filled[y][x] = true } }

  filled.each_with_index do |row, y|
    row.each_with_index do |on, x|
      next unless on

      edge = !filled[y - 1]&.[](x) || !filled[y + 1]&.[](x) || !row[x - 1] || !row[x + 1]
      canvas.rect(x, y, x, y, edge ? BLUE_DARK : BLUE)
    end
  end

  # белый плюс по центру корпуса
  cx, cy, arm = g[:plus]
  canvas.rect(cx - arm, cy - 1, cx + arm - 1, cy, WHITE)
  canvas.rect(cx - 1, cy - arm, cx, cy + arm - 1, WHITE)
  canvas
end

out = File.join(__dir__, '..', 'dn1sup_create_project', 'dn1sup_create_project', 'icons')
FileUtils.mkdir_p(out)

write_png(File.join(out, 'cp_16.png'), draw_icon(16, 16,
  body: [2, 4, 13, 12], tab: [2, 2, 7, 4], plus: [7, 8, 2]))

write_png(File.join(out, 'cp_24.png'), draw_icon(24, 24,
  body: [3, 6, 20, 18], tab: [3, 3, 11, 6], plus: [11, 12, 3]))

puts 'Готово.'
