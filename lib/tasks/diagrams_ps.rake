namespace :db do
  namespace :diagrams do

    desc "Generate DB diagrams and convert to PS with Graphviz"
    task :ps => 'db:diagrams' do
      ModalDiagrams.parameters.output_tools.each do |cmd|
        out_dir = Rails.root.join("db/diagrams/#{cmd}_ps")
        mkdir_p out_dir
        Dir[Rails.root.join('db/diagrams/*.dot')].each do |fn|
          fn = Pathname(fn)
          out_fn = out_dir.join(fn.basename.sub_ext('.ps'))
          `#{cmd} '#{fn}' -o '#{out_fn}' -Tps2`
        end
        puts "Output has been generated in #{out_dir}"
      end
    end

  end
end
