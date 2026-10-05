# frozen_string_literal: true
# =============================================================================
# tools/make_icons.rb — генерация профессиональных иконок тулбара и проекта:
#   • векторный SVG: icons/cp.svg (для современных версий SketchUp);
#   • растровые PNG: icons/cp_16.png, cp_24.png, cp_32.png, cp_48.png, cp_64.png
#   (рендеринг чистым Ruby с 4x суперсэмплингом и антиалиасингом).
# =============================================================================

require 'zlib'
require 'fileutils'

SVG_CONTENT = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
    <defs>
      <linearGradient id="folderBack" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#006fb8"/>
        <stop offset="100%" stop-color="#015995"/>
      </linearGradient>
      <linearGradient id="folderFront" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#36abf7"/>
        <stop offset="100%" stop-color="#0c8ee9"/>
      </linearGradient>
      <linearGradient id="badgeGrad" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#22c55e"/>
        <stop offset="100%" stop-color="#16a34a"/>
      </linearGradient>
    </defs>
    <!-- Задняя стенка папки и вкладка -->
    <path d="M2 5a2 2 0 0 1 2-2h4.5a2 2 0 0 1 1.4.6L11.5 5H20a2 2 0 0 1 2 2v4H2V5z" fill="url(#folderBack)"/>
    <!-- Лист проекта (чертёж) -->
    <rect x="4.5" y="4.5" width="15" height="7" rx="1" fill="#ffffff" opacity="0.95"/>
    <line x1="7" y1="7" x2="13" y2="7" stroke="#006fb8" stroke-width="1.2" stroke-linecap="round"/>
    <line x1="7" y1="9" x2="11" y2="9" stroke="#94a3b8" stroke-width="1" stroke-linecap="round"/>
    <!-- Передняя стенка папки -->
    <path d="M2 8.5C2 7.67 2.67 7 3.5 7h17c.83 0 1.5.67 1.5 1.5v10.5a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8.5z" fill="url(#folderFront)"/>
    <!-- Бейдж создания проекта -->
    <circle cx="16" cy="15" r="4.5" fill="url(#badgeGrad)"/>
    <path d="M16 12.8v4.4M13.8 15h4.4" stroke="#ffffff" stroke-width="1.6" stroke-linecap="round"/>
  </svg>
SVG

# -- PNG сборщик -------------------------------------------------------------

def png_chunk(type, data)
  [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
end

def write_png(path, pixels, width, height)
  raw = pixels.map { |row| "\x00" + row.map { |px| px.pack('C4') }.join }.join
  png = "\x89PNG\r\n\x1a\n".b +
        png_chunk('IHDR', [width, height, 8, 6, 0, 0, 0].pack('N5')) +
        png_chunk('IDAT', Zlib::Deflate.deflate(raw, Zlib::BEST_COMPRESSION)) +
        png_chunk('IEND', '')
  File.binwrite(path, png)
  puts "  ✓ #{File.basename(path)} (#{width}x#{height})"
end

# -- Канва с альфа-блендингом -------------------------------------------------

class ImageBuffer
  attr_reader :w, :h, :pixels

  def initialize(w, h)
    @w = w
    @h = h
    @pixels = Array.new(h) { Array.new(w) { [0, 0, 0, 0] } }
  end

  def blend_pixel(x, y, r, g, b, a)
    return if x < 0 || x >= @w || y < 0 || y >= @h || a <= 0

    cur = @pixels[y][x]
    sa = a / 255.0
    da = cur[3] / 255.0
    out_a = sa + da * (1.0 - sa)
    return if out_a.zero?

    out_r = ((r * sa + cur[0] * da * (1.0 - sa)) / out_a).round.clamp(0, 255)
    out_g = ((g * sa + cur[1] * da * (1.0 - sa)) / out_a).round.clamp(0, 255)
    out_b = ((b * sa + cur[2] * da * (1.0 - sa)) / out_a).round.clamp(0, 255)
    @pixels[y][x] = [out_r, out_g, out_b, (out_a * 255).round.clamp(0, 255)]
  end

  # Сглаженный спуск (4x бокс-фильтр) в результирующий буфер
  def downsample(scale = 4)
    target_w = @w / scale
    target_h = @h / scale
    out = Array.new(target_h) { Array.new(target_w) { [0, 0, 0, 0] } }

    target_h.times do |ty|
      target_w.times do |tx|
        sum_r = 0.0
        sum_g = 0.0
        sum_b = 0.0
        sum_a = 0.0

        scale.times do |sy|
          scale.times do |sx|
            px = @pixels[ty * scale + sy][tx * scale + sx]
            a = px[3] / 255.0
            sum_r += px[0] * a
            sum_g += px[1] * a
            sum_b += px[2] * a
            sum_a += a
          end
        end

        count = (scale * scale).to_f
        avg_a = sum_a / count
        if avg_a > 0.001
          avg_r = (sum_r / sum_a).round.clamp(0, 255)
          avg_g = (sum_g / sum_a).round.clamp(0, 255)
          avg_b = (sum_b / sum_a).round.clamp(0, 255)
          out[ty][tx] = [avg_r, avg_g, avg_b, (avg_a * 255).round.clamp(0, 255)]
        end
      end
    end
    out
  end
end

# -- Рендеринг иконки высокого разрешения (на сетке 24 x 24) ------------------

def render_icon(target_size)
  scale = 4
  hires = target_size * scale
  buf = ImageBuffer.new(hires, hires)
  s = hires / 24.0

  hires.times do |y|
    ny = y / s
    hires.times do |x|
      nx = x / s

      # 1. Задняя стенка папки и вкладка (tab)
      # Tab: x: 2..11, y: 3..6. Back body: x: 2..22, y: 5..10
      is_tab = nx >= 2.0 && nx <= 10.5 && ny >= 3.0 && ny <= 6.0
      is_back = nx >= 2.0 && nx <= 22.0 && ny >= 5.0 && ny <= 10.0
      if is_tab || is_back
        # Скругление верхнего левого угла вкладки
        tab_round = (nx - 3.5)**2 + (ny - 4.5)**2 <= 2.25 if nx < 3.5 && ny < 4.5
        corner_ok = nx >= 3.5 || ny >= 4.5 || tab_round
        if corner_ok
          t = ((ny - 3.0) / 7.0).clamp(0.0, 1.0)
          # Градиент #006fb8 -> #015995
          r = (0 * (1 - t) + 1 * t).round
          g = (111 * (1 - t) + 89 * t).round
          b = (184 * (1 - t) + 149 * t).round
          buf.blend_pixel(x, y, r, g, b, 255)
        end
      end

      # 2. Лист проекта (белый чертёж) внутри: x: 4.5..19.5, y: 4.5..10.5
      if nx >= 4.5 && nx <= 19.5 && ny >= 4.5 && ny <= 10.5
        # Чертежная линия на листе
        is_blue_line = nx >= 7.0 && nx <= 14.0 && ny >= 6.8 && ny <= 7.8
        is_gray_line = nx >= 7.0 && nx <= 12.0 && ny >= 8.8 && ny <= 9.6
        if is_blue_line
          buf.blend_pixel(x, y, 0, 111, 184, 255)
        elsif is_gray_line
          buf.blend_pixel(x, y, 148, 163, 184, 255)
        else
          buf.blend_pixel(x, y, 255, 255, 255, 245)
        end
      end

      # 3. Передняя стенка папки: x: 2..22, y: 7.2..21.0 со скруглением внизу и вверху
      if nx >= 2.0 && nx <= 22.0 && ny >= 7.2 && ny <= 21.0
        # Скругление углов (радиус 1.8)
        rad = 1.8
        c_tl = nx < 2.0 + rad && ny < 7.2 + rad ? (nx - (2.0 + rad))**2 + (ny - (7.2 + rad))**2 <= rad**2 : true
        c_tr = nx > 22.0 - rad && ny < 7.2 + rad ? (nx - (22.0 - rad))**2 + (ny - (7.2 + rad))**2 <= rad**2 : true
        c_bl = nx < 2.0 + rad && ny > 21.0 - rad ? (nx - (2.0 + rad))**2 + (ny - (21.0 - rad))**2 <= rad**2 : true
        c_br = nx > 22.0 - rad && ny > 21.0 - rad ? (nx - (22.0 - rad))**2 + (ny - (21.0 - rad))**2 <= rad**2 : true

        if c_tl && c_tr && c_bl && c_br
          t = ((ny - 7.2) / 13.8).clamp(0.0, 1.0)
          # Градиент #36abf7 -> #0c8ee9
          r = (54 * (1 - t) + 12 * t).round
          g = (171 * (1 - t) + 142 * t).round
          b = (247 * (1 - t) + 233 * t).round
          buf.blend_pixel(x, y, r, g, b, 255)
        end
      end

      # 4. Круглый бейдж плюса создания (зелёный градиент #22c55e -> #16a34a): центр (16.0, 15.0), r = 4.6
      dx = nx - 16.0
      dy = ny - 15.0
      dist_sq = dx * dx + dy * dy
      if dist_sq <= 4.6 * 4.6
        # Плюс: вертикальный и горизонтальный штрихи
        is_vert = dx.abs <= 0.85 && dy.abs <= 3.0
        is_horiz = dy.abs <= 0.85 && dx.abs <= 3.0
        if is_vert || is_horiz
          buf.blend_pixel(x, y, 255, 255, 255, 255)
        else
          t = ((dy + 4.6) / 9.2).clamp(0.0, 1.0)
          r = (34 * (1 - t) + 22 * t).round
          g = (197 * (1 - t) + 163 * t).round
          b = (94 * (1 - t) + 74 * t).round
          buf.blend_pixel(x, y, r, g, b, 255)
        end
      end
    end
  end

  buf.downsample(scale)
end

# -- Генерация файлов в папке icons ------------------------------------------

dest_dirs = [
  File.join(__dir__, '..', 'dn1sup_create_project', 'dn1sup_create_project', 'icons')
]

dest_dirs.each do |out|
  FileUtils.mkdir_p(out)
  puts "Генерация иконок в #{out}:"

  # 1. SVG вектор
  svg_path = File.join(out, 'cp.svg')
  File.write(svg_path, SVG_CONTENT, encoding: 'UTF-8')
  puts "  ✓ cp.svg (Vector)"

  # 2. PNG размеры
  [16, 24, 32, 48, 64].each do |size|
    px = render_icon(size)
    write_png(File.join(out, "cp_#{size}.png"), px, size, size)
  end
end

puts "\nГотово! Все иконки успешно созданы."
