namespace :db do
  namespace :diagrams do

    desc "Generate DB diagrams and convert to PNG with Graphviz and Ghostview"
    task :png => 'db:diagrams:ps' do
      ModalDiagrams.parameters.output_tools.each do |cmd|
        in_dir = Rails.root.join("db/diagrams/#{cmd}_ps")
        out_dir = Rails.root.join("db/diagrams/#{cmd}_png")
        mkdir_p out_dir
        Dir[in_dir.join('*.ps')].each do |fn|
          fn = Pathname(fn)
          out_fn = out_dir.join(fn.basename.sub_ext('.png'))
          `gs -q -dNOPAUSE -dBATCH -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -sDEVICE=png16m -sOutputFile=#{out_fn} #{fn}`
        end
        puts "Output has been generated in #{out_dir}"
      end
    end

  end
end
