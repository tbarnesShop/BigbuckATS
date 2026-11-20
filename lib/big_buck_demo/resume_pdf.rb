# frozen_string_literal: true

module BigBuckDemo
  # Minimal single/multi-page text PDF writer (Helvetica) so demo resumes are real,
  # downloadable PDFs without adding a gem. Input is a list of blocks:
  #   [:name, "Ava Chen"]   [:headline, "..."]   [:section, "EXPERIENCE"]
  #   [:role, "Title, Company", "2021 - Present"]  [:bullet, "..."]  [:text, "..."]  [:gap]
  class ResumePdf
    PAGE_W = 612
    PAGE_H = 792
    MARGIN = 54
    STYLES = {
      name: [ "F2", 22, 28 ], headline: [ "F1", 11, 16 ], section: [ "F2", 10.5, 20 ],
      role: [ "F2", 10.5, 15 ], bullet: [ "F1", 10, 13.5 ], text: [ "F1", 10, 13.5 ], gap: [ "F1", 10, 7 ]
    }.freeze
    AVG_CHAR = 0.5 # Helvetica average glyph width in em; conservative for wrapping

    def self.render(blocks)
      new(blocks).render
    end

    def initialize(blocks)
      @blocks = blocks
    end

    def render
      pages = layout
      objects = []
      objects << "<< /Type /Catalog /Pages 2 0 R >>"
      kids = pages.each_index.map { |i| "#{5 + (i * 2)} 0 R" }.join(" ")
      objects << "<< /Type /Pages /Kids [#{kids}] /Count #{pages.size} >>"
      objects << "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
      objects << "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"
      pages.each_with_index do |ops, i|
        content_id = 6 + (i * 2)
        objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{PAGE_W} #{PAGE_H}] " \
                   "/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents #{content_id} 0 R >>"
        stream = ops.join("\n")
        objects << "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
      end
      out = "%PDF-1.4\n".b
      offsets = []
      objects.each_with_index do |body, i|
        offsets << out.bytesize
        out << "#{i + 1} 0 obj\n".b << body.b << "\nendobj\n".b
      end
      xref = out.bytesize
      out << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n".b
      offsets.each { |o| out << format("%010d 00000 n \n", o).b }
      out << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n".b
      out
    end

    private

    def layout
      pages = [ [] ]
      y = PAGE_H - MARGIN
      @blocks.each do |kind, text, right|
        font, size, lead = STYLES.fetch(kind)
        indent = kind == :bullet ? 14 : 0
        lines = text.nil? ? [ "" ] : wrap(text.to_s, size, PAGE_W - (2 * MARGIN) - indent - (kind == :role ? 110 : 0))
        lines.each_with_index do |line, i|
          if y - lead < MARGIN
            pages << []
            y = PAGE_H - MARGIN
          end
          y -= lead
          x = MARGIN + indent
          pages.last << show(font, size, x, y, line)
          pages.last << show("F1", size, x - 11, y, "•") if kind == :bullet && i.zero?
          pages.last << show("F1", size - 0.5, PAGE_W - MARGIN - (right.to_s.length * size * AVG_CHAR), y, right) if kind == :role && right && i.zero?
        end
        if kind == :section
          pages.last << "0.7 w #{MARGIN} #{(y - 3).round(1)} m #{PAGE_W - MARGIN} #{(y - 3).round(1)} l S"
          y -= 3
        end
      end
      pages
    end

    def show(font, size, x, y, text)
      "BT /#{font} #{size} Tf #{x.round(1)} #{y.round(1)} Td (#{escape(text)}) Tj ET"
    end

    def escape(text)
      text.to_s.tr("–—", "--").tr("‘’", "''").tr("“”", '""')
          .encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
          .b.gsub(/([\\()])/n) { "\\#{Regexp.last_match(1)}" }
    end

    def wrap(text, size, width)
      per_line = [ (width / (size * AVG_CHAR)).floor, 20 ].max
      lines = []
      current = +""
      text.split(/\s+/).each do |word|
        if current.empty?
          current = word.dup
        elsif current.length + 1 + word.length <= per_line
          current << " " << word
        else
          lines << current
          current = word.dup
        end
      end
      lines << current unless current.empty?
      lines
    end
  end
end
