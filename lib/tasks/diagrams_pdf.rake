namespace :db do
  namespace :diagrams do

    desc "Generate DB diagrams and convert to PDF with Graphviz and Ghostview"
    task :pdf => 'db:diagrams:ps' do
      ModalDiagrams.parameters.output_tools.each do |cmd|
        in_dir = Rails.root.join("db/diagrams/#{cmd}_ps")
        out_dir = Rails.root.join("db/diagrams/#{cmd}_pdf")
        mkdir_p out_dir
        Dir[in_dir.join('*.ps')].each do |fn|
          fn = Pathname(fn)
          out_fn = out_dir.join(fn.basename.sub_ext('.pdf'))
          `ps2pdf '#{fn}' '#{out_fn}'`
        end
        puts "Output has been generated in #{out_dir}"
      end
    end

  end
end
