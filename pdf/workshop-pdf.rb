# The shared look of the workshop PDFs. Each workshop's antora-assembler.yml loads it:
#
#   build:
#     command: bundle exec asciidoctor-pdf -r ../workshop-common/pdf/workshop-pdf.rb
#
# It selects the theme next to this file (workshop-theme.yml, with its fonts and cover) and adds a
# table of contents, unless the workshop sets these attributes itself, and reshapes the blocks the
# PDF would otherwise print badly:
#
# * [tabs] blocks, such as ROSA (AWS) / ARO (Azure): one labeled panel per tab, one after the other
# * collapsible blocks, such as "EKS and AKS (reference only)" or an answer: a tinted panel with
#   its title, like the sites show them once opened
# * short code blocks and notes: moved to the next page whole instead of split
require 'asciidoctor'
require 'asciidoctor/extensions'

module WorkshopPdf
  THEME_DIR = __dir__

  # code blocks and notes up to this many lines move to the next page whole
  KEEP_TOGETHER_LINES = 25

  class Defaults < Asciidoctor::Extensions::Preprocessor
    def process document, reader
      {
        'pdf-theme' => 'workshop',
        'pdf-themesdir' => THEME_DIR,
        'toc' => '',
        'toclevels' => '2',
      }.each do |name, value|
        # set_attr leaves attributes passed on the command line alone
        document.set_attr name, value, false
      end
      reader
    end
  end

  class Blocks < Asciidoctor::Extensions::TreeProcessor
    def process document
      document.find_by(context: :example, style: 'tabs').each {|tabs| unfold_tabs tabs }
      document.find_by(context: :example) {|b| b.option? 'collapsible' }.each {|b| panel b }
      document.find_by {|b| short? b }.each {|b| b.set_option 'unbreakable' }
      nil
    end

    private

    # replace a [tabs] block with one sidebar per tab, titled with the tab label
    def unfold_tabs tabs
      dlist = tabs.blocks.find {|b| b.context == :dlist }
      return unless dlist
      parent = tabs.parent
      index = parent.blocks.index tabs
      panels = dlist.items.map do |terms, desc|
        panel = Asciidoctor::Block.new parent, :sidebar, content_model: :compound
        panel.title = terms.map(&:text).join ', '
        panel.add_role 'tab'
        if desc
          panel << (Asciidoctor::Block.new panel, :paragraph, source: desc.instance_variable_get(:@text)) if desc.text?
          desc.blocks.each do |b|
            # a "+ --" continuation wraps the tab content in an open block; lift its children
            children = b.context == :open && !b.title? && b.style == 'open' ? b.blocks : [b]
            children.each do |child|
              child.parent = panel
              panel << child
            end
          end
        end
        panel
      end
      parent.blocks[index, 1] = panels
    end

    # a collapsible block prints as an example block (a tinted panel) titled with its summary
    def panel block
      block.remove_attr 'collapsible-option'
      block.caption = ''
      block.title = 'Details' unless block.title?
      block.add_role 'collapsible'
    end

    def short? block
      case block.context
      when :listing, :literal
        block.lines.size <= KEEP_TOGETHER_LINES
      when :admonition
        block.blocks? ? block.blocks.sum {|b| b.respond_to?(:lines) ? b.lines.size : 3 } <= KEEP_TOGETHER_LINES : true
      else
        false
      end
    end
  end
end

Asciidoctor::Extensions.register do
  preprocessor WorkshopPdf::Defaults
  tree_processor WorkshopPdf::Blocks
end
